import { onMounted, onBeforeUnmount } from 'vue'

const kurangiGerak = () =>
  typeof window !== 'undefined' &&
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

/**
 * Tilt 3D + sorot kursor untuk elemen berkelas `.tilt`.
 *
 * Memakai event delegation di document, bukan listener per elemen: kartu
 * layanan bisa difilter (dibuang & dibuat ulang oleh Vue) tanpa perlu
 * memasang ulang listener, dan tidak ada risiko listener menggantung.
 *
 * Prinsip:
 * 1. Progressive enhancement. Tanpa pointer presisi (layar sentuh) atau bila
 *    pengguna minta gerak minimal, tidak ada listener yang dipasang sama
 *    sekali — kartu tampil datar dan tetap bisa diklik.
 * 2. Nilai rotasi ditulis ke CSS variable, bukan `transform` inline, agar
 *    tidak bertabrakan dengan utility transform milik Tailwind.
 * 3. Rotasi dibatasi kecil (maks 6deg) supaya teks tetap enak dibaca.
 */
export function useTilt(selector = '.tilt', opsi = {}) {
  const maks = opsi.maks ?? 6
  let aktif = false
  let terakhir = null

  const pulih = (el) => {
    if (!el) return
    el.style.setProperty('--tilt-x', '0deg')
    el.style.setProperty('--tilt-y', '0deg')
    el.style.setProperty('--tilt-lift', '0px')
  }

  const gerak = (e) => {
    const el = e.target instanceof Element ? e.target.closest(selector) : null
    if (terakhir && terakhir !== el) pulih(terakhir)
    terakhir = el
    if (!el) return

    const r = el.getBoundingClientRect()
    if (!r.width || !r.height) return
    const px = (e.clientX - r.left) / r.width
    const py = (e.clientY - r.top) / r.height

    el.style.setProperty('--tilt-y', `${((px - 0.5) * 2 * maks).toFixed(2)}deg`)
    el.style.setProperty('--tilt-x', `${((0.5 - py) * 2 * maks).toFixed(2)}deg`)
    el.style.setProperty('--tilt-lift', '-4px')
    el.style.setProperty('--glow-x', `${(px * 100).toFixed(1)}%`)
    el.style.setProperty('--glow-y', `${(py * 100).toFixed(1)}%`)
  }

  const keluar = () => {
    pulih(terakhir)
    terakhir = null
  }

  onMounted(() => {
    if (kurangiGerak()) return
    // Hanya perangkat dengan pointer presisi; di layar sentuh efek ini tidak
    // pernah terpicu dan hanya menambah beban.
    if (!window.matchMedia?.('(hover: hover) and (pointer: fine)').matches) return

    aktif = true
    document.addEventListener('pointermove', gerak, { passive: true })
    document.addEventListener('pointerleave', keluar, { passive: true })
    window.addEventListener('blur', keluar)
  })

  onBeforeUnmount(() => {
    if (!aktif) return
    document.removeEventListener('pointermove', gerak)
    document.removeEventListener('pointerleave', keluar)
    window.removeEventListener('blur', keluar)
    pulih(terakhir)
    terakhir = null
    aktif = false
  })
}

/**
 * Mengisi `--progres` (0..1) pada elemen `.timeline-rail` mengikuti seberapa
 * jauh bagian timeline sudah melewati viewport. Dipakai untuk garis yang
 * tumbuh saat digulir.
 */
export function useProgresGulir(selector = '.timeline-rail') {
  let frame = null
  let rails = []
  let aktif = false

  const hitung = () => {
    frame = null
    const vh = window.innerHeight || 1

    rails.forEach((rail) => {
      // Ukur wadah timeline yang sebenarnya (atribut data-timeline), bukan
      // elemen garis itu sendiri yang tingginya hanya 1px.
      const induk = rail.closest('[data-timeline]') || rail.parentElement
      if (!induk) return
      const r = induk.getBoundingClientRect()
      // 0 saat puncak timeline menyentuh 82% tinggi viewport,
      // 1 saat dasar timeline melewati 30% tinggi viewport.
      const mulai = vh * 0.82
      const selesai = vh * 0.3
      const total = r.height + (mulai - selesai)
      const jalan = mulai - r.top
      const p = Math.min(1, Math.max(0, jalan / (total || 1)))
      rail.style.setProperty('--progres', p.toFixed(3))
    })
  }

  const jadwalkan = () => {
    if (frame !== null) return
    frame = requestAnimationFrame(hitung)
  }

  onMounted(() => {
    rails = Array.from(document.querySelectorAll(selector))
    if (!rails.length) return
    if (kurangiGerak()) {
      // Tanpa animasi: garis langsung penuh, tidak ada yang tersembunyi.
      rails.forEach((r) => r.style.setProperty('--progres', '1'))
      return
    }
    aktif = true
    hitung()
    window.addEventListener('scroll', jadwalkan, { passive: true })
    window.addEventListener('resize', jadwalkan, { passive: true })
  })

  onBeforeUnmount(() => {
    if (!aktif) return
    window.removeEventListener('scroll', jadwalkan)
    window.removeEventListener('resize', jadwalkan)
    if (frame !== null) cancelAnimationFrame(frame)
    frame = null
    rails = []
    aktif = false
  })
}
