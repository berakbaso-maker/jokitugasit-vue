import { allowCors, graphRequest, notifyTelegram, requireSchedulerSecret, serverSupabase, waitForMediaContainer } from './_lib/instagram.js'

/*
 * Scheduler penerbit konten Instagram.
 *
 * Dipanggil oleh cron (Vercel Cron atau GitHub Actions), bukan oleh user.
 * Stateless: seluruh state ada di tabel `ig_posts`. Setiap post diklaim
 * dengan update bersyarat (`status = 'scheduled'`) supaya dua invokasi
 * paralel tidak mempublikasi konten yang sama dua kali.
 */

const CLAIM_STALE_MINUTES = 15
const MAX_POSTS_PER_RUN = 5

export default async function handler(req, res) {
  if (allowCors(req, res)) return
  if (req.method !== 'POST' && req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' })
  if (!requireSchedulerSecret(req, res)) return
  if (!process.env.IG_USER_ID) return res.status(500).json({ error: 'IG_USER_ID belum dikonfigurasi' })

  const supabase = serverSupabase()
  const now = new Date()
  const nowIso = now.toISOString()
  const staleIso = new Date(now.getTime() - CLAIM_STALE_MINUTES * 60 * 1000).toISOString()

  // Post yang macet di 'publishing' (function timeout / crash) dikembalikan ke
  // 'scheduled' agar bisa dicoba ulang. Tanpa ini, job mati permanen.
  await supabase
    .from('ig_posts')
    .update({ status: 'scheduled', updated_at: nowIso })
    .eq('status', 'publishing')
    .lt('updated_at', staleIso)

  const { data: duePosts, error } = await supabase
    .from('ig_posts')
    .select('*')
    .eq('status', 'scheduled')
    .lte('scheduled_at', nowIso)
    .order('scheduled_at', { ascending: true })
    .limit(MAX_POSTS_PER_RUN)
  if (error) return res.status(500).json({ error: error.message })

  const results = []
  for (const post of duePosts || []) {
    // Klaim atomik: hanya satu invokasi yang berhasil mengubah status.
    const { data: claimed } = await supabase
      .from('ig_posts')
      .update({ status: 'publishing', updated_at: nowIso })
      .eq('id', post.id)
      .eq('status', 'scheduled')
      .select('id')
      .maybeSingle()
    if (!claimed) continue

    try {
      const params = { caption: post.caption }
      if (post.media_type === 'REELS') {
        params.media_type = 'REELS'
        params.video_url = post.media_url
      } else {
        params.image_url = post.media_url
      }
      const container = await graphRequest(`${process.env.IG_USER_ID}/media`, { method: 'POST', params })
      if (post.media_type === 'REELS') await waitForMediaContainer(container.id)
      const published = await graphRequest(`${process.env.IG_USER_ID}/media_publish`, {
        method: 'POST',
        params: { creation_id: container.id },
      })
      await supabase.from('ig_posts').update({
        status: 'published',
        container_id: container.id,
        instagram_media_id: published.id,
        published_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        error_message: null,
      }).eq('id', post.id)
      results.push({ id: post.id, ok: true, mediaId: published.id })
      await notifyTelegram(`Konten terjadwal berhasil tayang\nMedia ID: ${published.id}\n${post.caption.slice(0, 300)}`)
        .catch((notifyError) => console.error('Telegram notification:', notifyError.message))
    } catch (publishError) {
      await supabase.from('ig_posts').update({
        status: 'failed',
        updated_at: new Date().toISOString(),
        error_message: publishError.message,
      }).eq('id', post.id)
      results.push({ id: post.id, ok: false, error: publishError.message })
    }
  }

  return res.status(200).json({ ok: true, processed: results.length, results })
}
