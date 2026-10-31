/**
 * Info pembayaran yang dicetak di SOW/penawaran ke klien.
 *
 * PENTING: sebelumnya berkas ini berisi placeholder `BCA: 1234567890 a.n Engineer`.
 * Kalau SOW itu terkirim ke klien, mereka bisa transfer ke rekening yang tidak ada.
 * Sekarang nilainya dibaca dari env, dan kalau belum diisi, teks SOW tidak
 * mencantumkan nomor rekening sama sekali (meminta lewat WhatsApp).
 *
 * Isi di .env (Vercel: Project Settings → Environment Variables):
 *   VITE_BANK_NAME=BCA
 *   VITE_BANK_ACCOUNT=1234567890
 *   VITE_BANK_HOLDER=Nama Pemilik
 *   VITE_EWALLET=0851xxxxxxx
 */
const env = (kunci) => (import.meta.env?.[kunci] || '').trim()

export function infoPembayaran() {
  const bank = env('VITE_BANK_NAME')
  const nomor = env('VITE_BANK_ACCOUNT')
  const pemilik = env('VITE_BANK_HOLDER')
  const ewallet = env('VITE_EWALLET')

  const bankLengkap = bank && nomor ? `${bank}: ${nomor}${pemilik ? ` a.n ${pemilik}` : ''}` : ''
  const ewalletLengkap = ewallet ? `GoPay / OVO / Dana: ${ewallet}` : ''

  return {
    bank: bankLengkap,
    ewallet: ewalletLengkap,
    ada: Boolean(bankLengkap || ewalletLengkap),
    pesan: [bankLengkap, ewalletLengkap].filter(Boolean),
  }
}
