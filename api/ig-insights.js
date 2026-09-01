import { allowCors, graphRequest, requireAutomationSecret, serverSupabase } from './_lib/instagram.js'

export default async function handler(req, res) {
  if (allowCors(req, res, 'GET, POST, OPTIONS')) return
  if (!['GET', 'POST'].includes(req.method)) return res.status(405).json({ error: 'Method not allowed' })
  if (!requireAutomationSecret(req, res)) return
  const igUserId = process.env.IG_USER_ID
  if (!igUserId) return res.status(500).json({ error: 'IG_USER_ID belum dikonfigurasi' })

  try {
    const profile = await graphRequest(igUserId, { params: { fields: 'username,followers_count,media_count' } })
    let insights = { data: [] }
    try {
      insights = await graphRequest(`${igUserId}/insights`, {
        params: { metric: 'reach,profile_views,website_clicks', period: 'day' },
      })
    } catch (error) {
      console.warn('Sebagian insight tidak tersedia:', error.message)
    }
    const metrics = Object.fromEntries((insights.data || []).map((item) => [item.name, item.values?.at(-1)?.value ?? item.total_value?.value ?? 0]))
    const snapshot = {
      snapshot_date: new Date().toISOString().slice(0, 10),
      followers_count: profile.followers_count || 0,
      media_count: profile.media_count || 0,
      reach: metrics.reach || 0,
      profile_views: metrics.profile_views || 0,
      website_clicks: metrics.website_clicks || 0,
      raw_metrics: { profile, insights: insights.data || [] },
    }
    const supabase = serverSupabase()
    const { data, error } = await supabase.from('ig_insights').upsert(snapshot, { onConflict: 'snapshot_date' }).select().single()
    if (error) throw error
    return res.status(200).json({ ok: true, insight: data })
  } catch (error) {
    console.error('Instagram insights:', error)
    return res.status(error.status || 500).json({ error: error.message })
  }
}
