<script setup>
/**
 * KpiCard — kartu metrik modular, mengikuti pola kartu DashboardView:
 * bg-surface-white, rounded-xl, shadow lembut, hover border electric-blue.
 *
 * Nilai HARUS berasal dari Supabase. Kalau null/undefined, tampilkan "—"
 * dan jangan pernah mengarang angka.
 */
const props = defineProps({
  label: { type: String, required: true },
  value: { type: [Number, String], default: null },
  hint: { type: String, default: '' },
  icon: { type: String, default: 'insights' },
  format: { type: String, default: 'number' }, // number | currency | percent
  tone: { type: String, default: 'default' }, // default | positive | warning | danger
  loading: { type: Boolean, default: false },
})

const nf = new Intl.NumberFormat('id-ID')

function display() {
  if (props.loading) return '…'
  if (props.value === null || props.value === undefined || props.value === '') return '—'
  if (props.format === 'currency') {
    const n = Number(props.value)
    if (!Number.isFinite(n)) return '—'
    return 'Rp ' + nf.format(Math.round(n))
  }
  if (props.format === 'percent') {
    const n = Number(props.value)
    if (!Number.isFinite(n)) return '—'
    return nf.format(n) + '%'
  }
  const n = Number(props.value)
  if (!Number.isFinite(n)) return props.value
  return nf.format(n)
}

// Warna angka memakai token repo. Tone "danger" hanya diwarnai bila
// nilainya benar-benar > 0 — angka 0 tidak boleh terlihat seperti error.
const toneClass = () => {
  const n = Number(props.value)
  const isZero = props.value === null || props.value === undefined || n === 0
  if (props.tone === 'danger' && isZero) return 'text-on-surface'
  return {
    default: 'text-on-surface',
    positive: 'text-success-green',
    warning: 'text-tertiary',
    danger: 'text-urgency-red',
  }[props.tone] || 'text-on-surface'
}

// Ikon memakai latar 10% dengan warna teks penuh di semua tone supaya
// bobot visualnya seragam (tidak ada kotak yang jauh lebih pekat).
const iconTone = () => ({
  default: 'bg-electric-blue/10 text-electric-blue',
  positive: 'bg-success-green/10 text-success-green',
  warning: 'bg-tertiary/10 text-tertiary',
  danger: 'bg-urgency-red/10 text-urgency-red',
}[props.tone] || 'bg-electric-blue/10 text-electric-blue')
</script>

<template>
  <div
    class="bg-surface-white p-5 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)]
           border border-transparent hover:border-electric-blue hover:shadow-lg
           transition-all duration-200 flex flex-col h-[136px] overflow-hidden"
  >
    <div class="flex items-center justify-between mb-3">
      <span class="text-secondary text-label-sm font-label-sm uppercase tracking-wide">{{ label }}</span>
      <span class="w-9 h-9 rounded-lg flex items-center justify-center shrink-0" :class="iconTone()">
        <span class="material-symbols-outlined text-[20px]">{{ icon }}</span>
      </span>
    </div>
    <div
      class="text-display-hero-mobile font-headline-md font-extrabold leading-none tabular-nums mt-auto"
      :class="toneClass()"
    >{{ display() }}</div>
    <!-- Baris hint selalu memesan tinggi yang sama supaya baseline angka
         sejajar antar kartu, termasuk saat hint kosong. -->
    <p class="mt-2 text-[12px] text-muted min-h-[16px] truncate">{{ hint || '\u00A0' }}</p>
  </div>
</template>
