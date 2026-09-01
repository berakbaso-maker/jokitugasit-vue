import {
  extractInstagramEvents,
  notifyTelegram,
  rawRequestBody,
  serverSupabase,
  verifyMetaSignature,
} from './_lib/instagram.js'

export const config = { api: { bodyParser: false } }

export default async function handler(req, res) {
  if (req.method === 'GET') {
    const mode = req.query['hub.mode']
    const token = req.query['hub.verify_token']
    const challenge = req.query['hub.challenge']
    if (mode === 'subscribe' && token && token === process.env.IG_WEBHOOK_VERIFY_TOKEN) {
      return res.status(200).send(challenge)
    }
    return res.status(403).json({ error: 'Webhook verification failed' })
  }

  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' })

  const rawBody = await rawRequestBody(req)
  if (!verifyMetaSignature(rawBody, req.headers['x-hub-signature-256'])) {
    return res.status(401).json({ error: 'Invalid Meta signature' })
  }

  try {
    const payload = JSON.parse(rawBody.toString('utf8'))
    const events = extractInstagramEvents(payload)
    const supabase = serverSupabase()

    for (const event of events) {
      const { data: savedEvent, error: eventError } = await supabase
        .from('ig_events')
        .upsert({
          external_id: event.externalId,
          event_type: event.eventType,
          sender_id: event.senderId,
          username: event.username,
          message: event.message,
          payload: event.raw,
          occurred_at: event.occurredAt,
        }, { onConflict: 'event_type,external_id', ignoreDuplicates: true })
        .select('id')
        .maybeSingle()
      if (eventError) throw eventError

      if (event.senderId && ['comments', 'mentions', 'messages'].includes(event.eventType)) {
        const { error: leadError } = await supabase.from('ig_leads').upsert({
          ig_user_id: event.senderId,
          username: event.username,
          source: event.eventType === 'messages' ? 'dm' : event.eventType === 'mentions' ? 'mention' : 'comment',
          last_message: event.message,
          last_event_at: event.occurredAt,
          metadata: { media_id: event.mediaId, comment_id: event.commentId, event_id: savedEvent?.id },
        }, { onConflict: 'ig_user_id' })
        if (leadError) throw leadError
      }

      const preview = event.message ? `\nPesan: ${event.message.slice(0, 500)}` : ''
      await notifyTelegram(`Instagram ${event.eventType}\nAkun: @${event.username || event.senderId || 'unknown'}${preview}\nBuka dashboard: ${process.env.APP_URL || 'https://jokitugasit.my.id'}/ig-leads`)
        .catch((error) => console.error('Telegram notification:', error.message))
    }

    return res.status(200).json({ ok: true, received: events.length })
  } catch (error) {
    console.error('Instagram webhook:', error)
    return res.status(500).json({ error: 'Webhook processing failed' })
  }
}
