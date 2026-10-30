/**
 * Prefetch rute saat penunjuk berhenti di sebuah tautan internal.
 *
 * Tujuan: perpindahan halaman terasa instan tanpa mengorbankan muatan awal.
 * Rute di aplikasi ini sudah memakai `() => import(...)`, jadi memanggil
 * loader-nya lebih awal cukup memicu unduhan chunk — tidak ada komponen
 * yang dipasang sebelum navigasi benar-benar terjadi.
 *
 * Aturan aman:
 * - hanya untuk tautan internal (href diawali `/`), bukan `target="_blank"`
 * - tidak jalan kalau perangkat minta hemat data atau koneksi lambat
 * - tidak jalan kalau `prefers-reduced-motion` (menghindari kerja latar
 *   yang tidak diminta)
 * - setiap rute hanya dipicu sekali
 */

const sudah = new Set()

function bolehPrefetch() {
  if (typeof navigator === 'undefined') return false
  if (navigator.connection) {
    if (navigator.connection.saveData) return false
    const tipe = navigator.connection.effectiveType
    if (tipe === 'slow-2g' || tipe === '2g' || tipe === '3g') return false
  }
  if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return false
  return true
}

/**
 * @param {import('vue-router').Router} router
 */
export function pasangPrefetch(router) {
  if (!bolehPrefetch()) return

  const muat = (path) => {
    if (sudah.has(path)) return
    sudah.add(path)

    let rute
    try {
      rute = router.resolve(path)
    } catch {
      return
    }
    if (!rute || !rute.matched.length) return

    // Ambil semua loader komponen di sepanjang rantai rute (termasuk induk).
    for (const rekam of rute.matched) {
      const komponen = rekam.components && rekam.components.default
      if (typeof komponen === 'function') {
        // Gagal prefetch tidak boleh mengganggu apa pun.
        Promise.resolve()
          .then(() => komponen())
          .catch(() => {})
      }
    }
  }

  const padaPointer = (e) => {
    const a = e.target instanceof Element ? e.target.closest('a[href]') : null
    if (!a) return
    if (a.target && a.target !== '_self') return
    if (a.hasAttribute('download') || a.getAttribute('rel') === 'external') return

    const href = a.getAttribute('href') || ''
    if (!href.startsWith('/') || href.startsWith('//')) return
    if (href.startsWith('/#') || href === '#') return

    // Buang query/hash agar cache rute tidak pecah per variasi.
    const bersih = href.split('#')[0].split('?')[0]
    if (!bersih) return
    muat(bersih)
  }

  document.addEventListener('pointerover', padaPointer, { passive: true })
  // Keyboard: fokus ke tautan juga layak dipra-muat.
  document.addEventListener('focusin', padaPointer, { passive: true })
}
