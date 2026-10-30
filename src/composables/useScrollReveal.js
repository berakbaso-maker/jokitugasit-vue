import { onMounted, onBeforeUnmount } from 'vue'

/**
 * Scroll reveal berbasis IntersectionObserver.
 *
 * Prinsip penting:
 * 1. Progressive enhancement. Kelas `js-reveal` dipasang di <html> HANYA
 *    setelah composable ini jalan. Tanpa JS (atau bila observer tak didukung),
 *    konten tetap terlihat penuh — tidak ada konten yang "hilang".
 * 2. Menghormati prefers-reduced-motion: bila pengguna meminta gerak minimal,
 *    semua elemen langsung ditandai terlihat tanpa animasi.
 * 3. Bersih-bersih: observer di-disconnect saat unmount agar tidak bocor.
 *
 * @param {string} selector - selector elemen yang akan di-reveal
 */
export function useScrollReveal(selector = '.reveal') {
  let observer = null

  const tampilkanSemua = () => {
    document.querySelectorAll(selector).forEach((el) => {
      el.classList.add('is-visible')
    })
  }

  onMounted(() => {
    const kurangiGerak = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches

    // Tanpa IntersectionObserver atau pengguna minta gerak minimal:
    // tampilkan semuanya, jangan pasang js-reveal sama sekali.
    if (kurangiGerak || typeof IntersectionObserver === 'undefined') {
      tampilkanSemua()
      return
    }

    document.documentElement.classList.add('js-reveal')

    observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible')
            observer.unobserve(entry.target)
          }
        })
      },
      {
        // Mulai animasi sedikit sebelum elemen masuk viewport
        rootMargin: '0px 0px -10% 0px',
        threshold: 0.08,
      },
    )

    document.querySelectorAll(selector).forEach((el) => observer.observe(el))
  })

  onBeforeUnmount(() => {
    observer?.disconnect()
    observer = null
    document.documentElement.classList.remove('js-reveal')
  })
}
