import { allowCors, graphRequest, requireAutomationSecret } from './_lib/instagram.js'

export default async function handler(req, res) {
  if (allowCors(req, res)) return
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' })
  if (!requireAutomationSecret(req, res)) return

  const { commentId, message, privateReply = false } = req.body || {}
  if (!commentId || !message) return res.status(400).json({ error: 'commentId dan message wajib diisi' })

  try {
    const result = privateReply
      ? await graphRequest(`${process.env.IG_USER_ID}/messages`, {
          method: 'POST',
          params: { recipient: JSON.stringify({ comment_id: commentId }), message: JSON.stringify({ text: message }) },
        })
      : await graphRequest(`${commentId}/replies`, { method: 'POST', params: { message } })
    return res.status(200).json({ ok: true, result })
  } catch (error) {
    console.error('Instagram reply:', error)
    return res.status(error.status || 500).json({ error: error.message })
  }
}
