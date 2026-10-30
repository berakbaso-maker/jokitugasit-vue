import { ref, computed } from 'vue'

/**
 * Tema terang/gelap.
 *
 * Urutan keputusan (sama persis dengan script anti-FOUC di index.html —
 * kalau salah satu diubah, ubah keduanya):
 *   1. pilihan tersimpan di localStorage  -> menang
 *   2. preferensi sistem (prefers-color-scheme)
 *   3. terang
 *
 * Pilihan disimpan sebagai 'light' | 'dark' (bukan 'system') supaya tombol
 * toggle punya perilaku yang bisa ditebak: sekali klik selalu mengganti tema.
 */

const STORAGE_KEY = 'jokitugasit-tema'

function bacaTersimpan() {
  try {
    const v = localStorage.getItem(STORAGE_KEY)
    return v === 'light' || v === 'dark' ? v : null
  } catch {
    // Mode privat / storage diblokir: jangan sampai seluruh app crash.
    return null
  }
}

function preferensiSistem() {
  try {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  } catch {
    return 'light'
  }
}

function temaAwal() {
  return bacaTersimpan() || preferensiSistem()
}

// State modul-level: satu sumber kebenaran untuk semua komponen.
const tema = ref(temaAwal())

function terapkan(nilai) {
  const root = document.documentElement
  root.classList.toggle('dark', nilai === 'dark')
  root.style.colorScheme = nilai
}

export function pakaiTema() {
  const isDark = computed(() => tema.value === 'dark')

  function setTema(nilai) {
    tema.value = nilai === 'dark' ? 'dark' : 'light'
    terapkan(tema.value)
    try {
      localStorage.setItem(STORAGE_KEY, tema.value)
    } catch {
      // Gagal menyimpan tidak fatal: tema tetap berlaku untuk sesi ini.
    }
  }

  function toggleTema() {
    setTema(tema.value === 'dark' ? 'light' : 'dark')
  }

  // Ikuti perubahan sistem HANYA kalau pengguna belum pernah memilih manual.
  function pasangListenerSistem() {
    let mq
    try {
      mq = window.matchMedia('(prefers-color-scheme: dark)')
    } catch {
      return () => {}
    }
    const handler = (e) => {
      if (bacaTersimpan()) return
      tema.value = e.matches ? 'dark' : 'light'
      terapkan(tema.value)
    }
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }

  return { tema, isDark, setTema, toggleTema, pasangListenerSistem }
}

/** Dipanggil sekali dari main.js agar class .dark aktif sejak mount. */
export function inisialisasiTema() {
  terapkan(tema.value)
  return pakaiTema().pasangListenerSistem()
}
