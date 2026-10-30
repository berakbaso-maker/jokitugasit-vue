<script setup>
import { computed } from 'vue'

const props = defineProps({
  pesan: { type: String, required: true },
  detail: { type: String, default: '' },
  bisaUlang: { type: Boolean, default: false },
  aksiLabel: { type: String, default: 'Coba lagi' },
})

defineEmits(['coba-lagi'])

// Detail teknis hanya untuk pengembang; user publik tidak perlu stack trace.
const tampilDetail = computed(() => import.meta.env.DEV && Boolean(props.detail))
</script>

<template>
  <div role="alert" class="bg-error-container text-on-error-container rounded-lg px-4 py-3 font-body-md text-body-md">
    <p class="flex items-start gap-2">
      <span class="material-symbols-outlined text-[20px] shrink-0" aria-hidden="true">error</span>
      <span>{{ pesan }}</span>
    </p>
    <button
      v-if="bisaUlang"
      type="button"
      class="mt-3 inline-flex items-center gap-1.5 h-11 px-4 rounded-lg bg-white/70 text-on-error-container font-label-bold text-label-bold hover:bg-white transition-colors"
      @click="$emit('coba-lagi')"
    >
      <span class="material-symbols-outlined text-[18px]" aria-hidden="true">refresh</span>
      {{ aksiLabel }}
    </button>
    <details v-if="tampilDetail" class="mt-3 text-xs">
      <summary class="cursor-pointer opacity-80">Detail teknis</summary>
      <pre class="mt-1 whitespace-pre-wrap break-words font-mono">{{ detail }}</pre>
    </details>
  </div>
</template>
