<script setup>
/**
 * EmptyState — pesan kosong / error yang bisa ditindaklanjuti.
 */
defineProps({
  icon: { type: String, default: 'inbox' },
  title: { type: String, default: 'Belum ada data' },
  description: { type: String, default: '' },
  actionLabel: { type: String, default: '' },
  tone: { type: String, default: 'neutral' }, // neutral | warning | error
})
defineEmits(['action'])

const toneCls = (t) => ({
  neutral: 'bg-surface-container-low text-muted',
  warning: 'bg-tertiary-fixed/40 text-tertiary',
  error: 'bg-error-container text-on-error-container',
}[t] || 'bg-surface-container-low text-muted')
</script>

<template>
  <div class="bg-surface-white border border-border-subtle rounded-2xl px-6 py-14 text-center shadow-card">
    <div class="w-12 h-12 rounded-xl grid place-items-center mx-auto mb-4" :class="toneCls(tone)">
      <span class="material-symbols-outlined">{{ icon }}</span>
    </div>
    <h3 class="font-bold text-[16px]">{{ title }}</h3>
    <p v-if="description" class="text-[13px] text-muted mt-2 max-w-md mx-auto whitespace-pre-line">{{ description }}</p>
    <button
      v-if="actionLabel"
      class="mt-5 inline-flex items-center gap-2 bg-accent-fill text-white font-label-bold px-4 py-2.5 rounded-xl hover:bg-primary-container transition-colors"
      @click="$emit('action')"
    >
      {{ actionLabel }}
    </button>
  </div>
</template>
