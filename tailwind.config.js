/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{vue,js,ts,jsx,tsx}',
  ],
  darkMode: 'class',
  theme: {
    extend: {
      // ---------------------------------------------------------------------
      // Clean SaaS palette.
      // Nama token SENGAJA dipertahankan agar 1.200+ pemakaian kelas di seluruh
      // view tetap valid. Yang berubah hanya nilainya.
      //
      // Catatan kontras: brief menyebut muted #64748B, tetapi rasio terhadap
      // surface #F1F5F9 hanya 4.34:1 (gagal WCAG AA untuk teks normal).
      // Karena itu teks muted memakai #52627A -> 5.66:1 di atas #F1F5F9,
      // 6.20:1 di atas putih. #64748B disimpan sebagai 'muted' untuk
      // dekorasi/ikon non-teks saja.
      // ---------------------------------------------------------------------
      colors: {
        // ------------------------------------------------------------------
        // Token semantik -> CSS variable.
        // Nilai terang tinggal di :root, nilai gelap di .dark (src/assets/main.css).
        // 3.160+ pemakaian kelas di seluruh view TIDAK perlu disentuh: cukup
        // nilai variabelnya yang berubah saat <html class="dark">.
        // ------------------------------------------------------------------
        // Kanvas & permukaan
        'background': 'rgb(var(--background) / <alpha-value>)',
        'surface': 'rgb(var(--surface) / <alpha-value>)',
        'surface-white': 'rgb(var(--surface-white) / <alpha-value>)',
        'surface-bright': 'rgb(var(--surface-bright) / <alpha-value>)',
        'surface-container-lowest': 'rgb(var(--surface-container-lowest) / <alpha-value>)',
        'surface-container-low': 'rgb(var(--surface-container-low) / <alpha-value>)',
        'surface-container': 'rgb(var(--surface-container) / <alpha-value>)',
        'surface-container-high': 'rgb(var(--surface-container-high) / <alpha-value>)',
        'surface-container-highest': 'rgb(var(--surface-container-highest) / <alpha-value>)',
        'surface-variant': 'rgb(var(--surface-variant) / <alpha-value>)',
        'surface-dim': 'rgb(var(--surface-dim) / <alpha-value>)',

        // Teks
        'on-background': 'rgb(var(--on-background) / <alpha-value>)',
        'on-surface': 'rgb(var(--on-surface) / <alpha-value>)',
        'on-surface-variant': 'rgb(var(--on-surface-variant) / <alpha-value>)',
        'secondary': 'rgb(var(--secondary) / <alpha-value>)',
        'muted': 'rgb(var(--muted) / <alpha-value>)',
        'outline': 'rgb(var(--outline) / <alpha-value>)',
        'outline-variant': 'rgb(var(--outline-variant) / <alpha-value>)',
        'border-subtle': 'rgb(var(--border-subtle) / <alpha-value>)',

        // Aksen peran-TEKS: menerang di mode gelap agar lolos AA.
        'primary': 'rgb(var(--primary) / <alpha-value>)',
        'electric-blue': 'rgb(var(--electric-blue) / <alpha-value>)',
        'primary-fixed': 'rgb(var(--primary-fixed) / <alpha-value>)',
        'primary-fixed-dim': 'rgb(var(--primary-fixed-dim) / <alpha-value>)',
        'on-primary-fixed': 'rgb(var(--on-primary-fixed) / <alpha-value>)',
        'on-primary-fixed-variant': 'rgb(var(--on-primary-fixed-variant) / <alpha-value>)',
        'surface-tint': 'rgb(var(--surface-tint) / <alpha-value>)',
        'inverse-primary': 'rgb(var(--inverse-primary) / <alpha-value>)',

        // Aksen peran-ISI: statis. Teks putih di atasnya wajib tetap terbaca,
        // jadi nilai ini TIDAK boleh ikut menerang di mode gelap.
        'accent-fill': '#2563EB',
        'accent-fill-hover': '#1D4ED8',
        // Gradien hero gelap. SENGAJA statis: blok ini selalu berteks putih,
        // jadi tidak boleh ikut menerang di mode gelap.
        'hero-gradient-from': '#2563EB',
        'hero-gradient-via': '#2563EB',
        'hero-gradient-to': '#1E293B',
        'primary-container': '#1D4ED8',
        'on-primary': '#FFFFFF',
        'on-primary-container': '#DBEAFE',

        // Aksen sekunder (netral editorial)
        'secondary-container': 'rgb(var(--secondary-container) / <alpha-value>)',
        'on-secondary': '#FFFFFF',
        'on-secondary-container': 'rgb(var(--on-secondary-container) / <alpha-value>)',
        'secondary-fixed': 'rgb(var(--secondary-fixed) / <alpha-value>)',
        'secondary-fixed-dim': 'rgb(var(--secondary-fixed-dim) / <alpha-value>)',
        'on-secondary-fixed': 'rgb(var(--on-secondary-fixed) / <alpha-value>)',
        'on-secondary-fixed-variant': 'rgb(var(--on-secondary-fixed-variant) / <alpha-value>)',

        // Aksen tersier (blok editorial)
        'tertiary': 'rgb(var(--tertiary) / <alpha-value>)',
        'tertiary-container': 'rgb(var(--tertiary-container) / <alpha-value>)',
        'on-tertiary': '#FFFFFF',
        'on-tertiary-container': 'rgb(var(--on-tertiary-container) / <alpha-value>)',
        'tertiary-fixed': 'rgb(var(--tertiary-fixed) / <alpha-value>)',
        'tertiary-fixed-dim': 'rgb(var(--tertiary-fixed-dim) / <alpha-value>)',
        'on-tertiary-fixed': 'rgb(var(--on-tertiary-fixed) / <alpha-value>)',
        'on-tertiary-fixed-variant': 'rgb(var(--on-tertiary-fixed-variant) / <alpha-value>)',

        // Status
        'error': 'rgb(var(--error) / <alpha-value>)',
        'error-container': 'rgb(var(--error-container) / <alpha-value>)',
        'on-error': '#FFFFFF',
        'on-error-container': 'rgb(var(--on-error-container) / <alpha-value>)',
        'success-green': 'rgb(var(--success-green) / <alpha-value>)',
        'success-fill': '#15803D',
        'urgency-red': 'rgb(var(--urgency-red) / <alpha-value>)',

        // Permukaan gelap (blok CTA invers) - BERBALIK di mode gelap
        'inverse-surface': 'rgb(var(--inverse-surface) / <alpha-value>)',
        'inverse-on-surface': 'rgb(var(--inverse-on-surface) / <alpha-value>)',
      },
      borderRadius: {
        DEFAULT: '0.25rem',
        lg: '0.5rem',
        xl: '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem',
        full: '9999px',
      },
      spacing: {
        'container-max-width': '1200px',
        gutter: '24px',
        base: '8px',
        'section-gap-mobile': '48px',
        'section-gap-desktop': '80px',
      },
      fontFamily: {
        sans: ['Plus Jakarta Sans', 'system-ui', 'sans-serif'],
        'body-lg': ['Plus Jakarta Sans'],
        'headline-md': ['Plus Jakarta Sans'],
        'label-sm': ['Plus Jakarta Sans'],
        'display-hero': ['Plus Jakarta Sans'],
        'body-md': ['Plus Jakarta Sans'],
        'headline-lg': ['Plus Jakarta Sans'],
        'label-bold': ['Plus Jakarta Sans'],
        'display-hero-mobile': ['Plus Jakarta Sans'],
      },
      fontSize: {
        'body-lg': ['18px', { lineHeight: '1.6', fontWeight: '400' }],
        'headline-md': ['24px', { lineHeight: '1.3', fontWeight: '700' }],
        'label-sm': ['12px', { lineHeight: '1', fontWeight: '600' }],
        'display-hero': ['48px', { lineHeight: '1.1', letterSpacing: '-0.02em', fontWeight: '800' }],
        'body-md': ['16px', { lineHeight: '1.5', fontWeight: '400' }],
        'headline-lg': ['30px', { lineHeight: '1.2', fontWeight: '700' }],
        'label-bold': ['14px', { lineHeight: '1', letterSpacing: '0.05em', fontWeight: '700' }],
        'display-hero-mobile': ['32px', { lineHeight: '1.2', fontWeight: '800' }],
      },
      boxShadow: {
        // Warna bayangan ikut tema supaya tidak jadi abu-abu mati di latar gelap.
        'card': '0 1px 2px rgb(var(--shadow-color) / 0.04), 0 1px 3px rgb(var(--shadow-color) / 0.06)',
        'card-hover': '0 4px 12px rgb(var(--shadow-color) / 0.06), 0 12px 32px -8px rgb(var(--shadow-color) / 0.10)',
        'header': '0 1px 0 rgb(var(--shadow-color) / 0.06)',
        'cta': '0 8px 24px -6px rgb(var(--cta-shadow-color) / 0.35)',
      },
      transitionTimingFunction: {
        'out-expo': 'cubic-bezier(0.16, 1, 0.3, 1)',
      },
      keyframes: {
        'reveal-up': {
          '0%': { opacity: '0', transform: 'translateY(14px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
      animation: {
        'reveal-up': 'reveal-up 0.6s cubic-bezier(0.16, 1, 0.3, 1) both',
      },
    },
  },
  plugins: [],
}
