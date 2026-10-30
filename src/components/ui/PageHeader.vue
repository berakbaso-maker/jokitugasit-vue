<script setup>
/**
 * PageHeader — header halaman konsisten.
 *
 * Mengikuti pola header DashboardView milik project utama:
 *   h1  : text-headline-md font-headline-md font-bold text-on-surface
 *   desc: text-body-md font-body-md text-secondary mt-1
 *   wrap: mb-8
 * `eyebrow` opsional dan default kosong supaya tidak menambah
 * breadcrumb yang tidak ada di halaman lain.
 */
defineProps({
  eyebrow: { type: String, default: '' },
  title: { type: String, required: true },
  description: { type: String, default: '' },
})
</script>

<template>
  <div class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-8">
    <div class="min-w-0">
      <p v-if="eyebrow" class="text-label-sm font-label-sm text-electric-blue uppercase tracking-wider mb-2">{{ eyebrow }}</p>
      <h1 class="text-headline-md font-headline-md font-bold text-on-surface">{{ title }}</h1>
      <p v-if="description" class="text-body-md font-body-md text-secondary mt-1">{{ description }}</p>
    </div>
    <div class="flex items-center gap-2 flex-wrap shrink-0">
      <slot name="actions" />
    </div>
  </div>
</template>
