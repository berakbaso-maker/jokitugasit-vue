<script setup>
/**
 * StatusBadge — satu sumber warna untuk semua status.
 *
 * Semua warna memakai token dari tailwind.config.js project utama
 * (success-green, urgency-red, error-container, primary, tertiary).
 * Tidak ada warna hardcoded seperti emerald/amber/red agar badge
 * menyatu dengan bahasa visual jokitugasit-vue.
 */
const props = defineProps({
  value: { type: String, default: '' },
  label: { type: String, default: '' },
  size: { type: String, default: 'sm' }, // sm | md
})

// Nilai status -> peran warna. Peran dipetakan ke token di bawah.
const MAP = {
  // Lead stage
  NEW: 'neutral', RESEARCHING: 'neutral', ELIGIBLE_CONTACT: 'info',
  CONTACTED: 'info', REPLIED: 'accent', INTERESTED: 'accent',
  QUALIFIED: 'success', CLIENT: 'success', PARTNER: 'success',
  NOT_INTERESTED: 'neutral', DO_NOT_CONTACT: 'danger', CLOSED: 'neutral',
  // Proyek
  INQUIRY: 'neutral', QUOTED: 'info', PLANNING: 'info', IN_PROGRESS: 'info',
  REVIEW: 'warning', DELIVERED: 'success', CANCELLED: 'danger',
  // Pembayaran / komisi
  PENDING: 'warning', CONFIRMED: 'success', VOID: 'danger',
  PAID: 'success', ELIGIBLE: 'info', ADJUSTMENT: 'warning',
  // Kampanye
  DRAFT: 'neutral', ACTIVE: 'success', PAUSED: 'warning', COMPLETED: 'info',
  // Tugas
  OPEN: 'warning', DONE: 'success', TODO: 'neutral', DOING: 'info', BLOCKED: 'danger',
  // Workflow
  RUNNING: 'info', SUCCEEDED: 'success', FAILED: 'danger', SKIPPED: 'neutral',
  // Consent
  UNKNOWN: 'neutral', REQUESTED: 'warning', GRANTED: 'success',
  DECLINED: 'danger', WITHDRAWN: 'danger',
  // Prioritas
  LOW: 'neutral', MEDIUM: 'info', HIGH: 'warning', URGENT: 'danger',
}

// Peran -> kelas token. Ring tipis supaya konsisten dengan badge repo.
const TONES = {
  neutral: 'bg-surface-container text-on-surface-variant ring-outline-variant',
  info: 'bg-primary-fixed text-primary ring-primary/20',
  accent: 'bg-secondary-container text-on-secondary-container ring-secondary/20',
  success: 'bg-success-green/10 text-success-green ring-success-green/25',
  warning: 'bg-urgency-red/5 text-tertiary ring-urgency-red/20',
  danger: 'bg-error-container text-on-error-container ring-error/25',
}

const tone = () => TONES[MAP[props.value] || 'neutral']
const text = () => props.label || (props.value || '—').replaceAll('_', ' ').toLowerCase()
</script>

<template>
  <span
    class="inline-flex items-center rounded-full ring-1 font-semibold whitespace-nowrap"
    :class="[tone(), size === 'md' ? 'px-2.5 py-1 text-[12px]' : 'px-2 py-0.5 text-[11px]']"
  >
    {{ text() }}
  </span>
</template>
