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
        // Kanvas & permukaan
        'background': '#FFFFFF',
        'surface': '#FFFFFF',
        'surface-white': '#FFFFFF',
        'surface-bright': '#FFFFFF',
        'surface-container-lowest': '#FFFFFF',
        'surface-container-low': '#F8FAFC',
        'surface-container': '#F1F5F9',
        'surface-container-high': '#E2E8F0',
        'surface-container-highest': '#CBD5E1',
        'surface-variant': '#E2E8F0',
        'surface-dim': '#E2E8F0',

        // Teks
        'on-background': '#0F172A',
        'on-surface': '#0F172A',
        'on-surface-variant': '#475569',
        'secondary': '#52627A',
        'muted': '#64748B',
        'outline': '#94A3B8',
        'outline-variant': '#CBD5E1',
        'border-subtle': '#E2E8F0',

        // Aksen utama
        'primary': '#2563EB',
        'primary-container': '#1D4ED8',
        'electric-blue': '#2563EB',
        'on-primary': '#FFFFFF',
        'on-primary-container': '#DBEAFE',
        'primary-fixed': '#DBEAFE',
        'primary-fixed-dim': '#BFDBFE',
        'on-primary-fixed': '#1E3A8A',
        'on-primary-fixed-variant': '#1D4ED8',
        'surface-tint': '#2563EB',
        'inverse-primary': '#93C5FD',

        // Aksen sekunder (netral editorial)
        'secondary-container': '#E2E8F0',
        'on-secondary': '#FFFFFF',
        'on-secondary-container': '#475569',
        'secondary-fixed': '#E2E8F0',
        'secondary-fixed-dim': '#CBD5E1',
        'on-secondary-fixed': '#0F172A',
        'on-secondary-fixed-variant': '#334155',

        // Aksen tersier (slate gelap untuk blok editorial)
        'tertiary': '#1E293B',
        'tertiary-container': '#334155',
        'on-tertiary': '#FFFFFF',
        'on-tertiary-container': '#DBEAFE',
        'tertiary-fixed': '#DBEAFE',
        'tertiary-fixed-dim': '#93C5FD',
        'on-tertiary-fixed': '#0F172A',
        'on-tertiary-fixed-variant': '#1E40AF',

        // Status. Digelapkan dari versi lama agar lolos AA saat dipakai
        // sebagai teks di atas latar terang.
        'error': '#B91C1C',
        'error-container': '#FEE2E2',
        'on-error': '#FFFFFF',
        'on-error-container': '#7F1D1D',
        'success-green': '#15803D',
        'urgency-red': '#DC2626',

        // Permukaan gelap (blok CTA invers)
        'inverse-surface': '#0F172A',
        'inverse-on-surface': '#F8FAFC',
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
        // Bayangan tipis berlapis: kartu terasa "mengambang" tanpa norak.
        'card': '0 1px 2px rgba(15, 23, 42, 0.04), 0 1px 3px rgba(15, 23, 42, 0.06)',
        'card-hover': '0 4px 12px rgba(15, 23, 42, 0.06), 0 12px 32px -8px rgba(15, 23, 42, 0.10)',
        'header': '0 1px 0 rgba(15, 23, 42, 0.06)',
        'cta': '0 8px 24px -6px rgba(37, 99, 235, 0.35)',
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
