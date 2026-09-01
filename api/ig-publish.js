import { allowCors, graphRequest, notifyTelegram, requireAutomationSecret, serverSupabase, waitForMediaContainer } from './_lib/instagram.js'

export default async function handler(req, res) {
  if (allowCors(req, res)) return
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' })
  if (!requireAutomationSecret(req, res)) return

  const { mediaUrl, caption = '', mediaType = 'IMAGE', postId } = req.body || {}
  const igUserId = process.env.IG_USER_ID
  if (!igUserId || !mediaUrl) return res.status(400).json({ error: 'IG_USER_ID dan mediaUrl wajib diisi' })

  try {
    const params = { caption }
    if (mediaType === 'REELS') {
      params.media_type = 'REELS'
      params.video_url = mediaUrl
    } else {
      params.image_url = mediaUrl
    }

    const container = await graphRequest(`${igUserId}/media`, { method: 'POST', params })
    if (mediaType === 'REELS') await waitForMediaContainer(container.id)
    const published = await graphRequest(`${igUserId}/media_publish`, {
      method: 'POST',
      params: { creation_id: container.id },
    })

    if (postId) {
      const supabase = serverSupabase()
      await supabase.from('ig_posts').update({
        status: 'published',
        container_id: container.id,
        instagram_media_id: published.id,
        published_at: new Date().toISOString(),
        error_message: null,
      }).eq('id', postId)
    }

    await notifyTelegram(`Posting Instagram berhasil\nMedia ID: ${published.id}\nCaption: ${caption.slice(0, 300)}`)
      .catch((error) => console.error('Telegram notification:', error.message))
    return res.status(200).json({ ok: true, containerId: container.id, mediaId: published.id })
  } catch (error) {
    console.error('Instagram publish:', error)
    if (postId) {
      const supabase = serverSupabase()
      await supabase.from('ig_posts').update({ status: 'failed', error_message: error.message }).eq('id', postId)
    }
    return res.status(error.status || 500).json({ error: error.message })
  }
}
