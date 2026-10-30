<script setup>
/**
 * AppModal — modal dasar dengan focus trap sederhana + Escape.
 *
 * Prop `open` WAJIB didukung: tanpa itu modal selalu tampil dan menutupi
 * seluruh halaman. Default false supaya aman.
 */
import { onBeforeUnmount, ref, watch, nextTick } from 'vue'

const props = defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  width: { type: String, default: 'max-w-2xl' },
})
const emit = defineEmits(['close'])

const panel = ref(null)

function onKey(e) {
  if (!props.open) return
  if (e.key === 'Escape') emit('close')
  if (e.key !== 'Tab' || !panel.value) return
  const nodes = panel.value.querySelectorAll(
    'a[href],button:not([disabled]),textarea,input,select,[tabindex]:not([tabindex="-1"])'
  )
  if (!nodes.length) return
  const first = nodes[0]
  const last = nodes[nodes.length - 1]
  if (e.shiftKey && document.activeElement === first) {
    e.preventDefault(); last.focus()
  } else if (!e.shiftKey && document.activeElement === last) {
    e.preventDefault(); first.focus()
  }
}

// Kunci scroll body hanya selama modal terbuka, dan lepas saat ditutup.
watch(
  () => props.open,
  async (isOpen) => {
    document.body.style.overflow = isOpen ? 'hidden' : ''
    if (isOpen) {
      document.addEventListener('keydown', onKey)
      await nextTick()
      const firstInput = panel.value?.querySelector(
        'input,textarea,select,button'
      )
      firstInput?.focus()
    } else {
      document.removeEventListener('keydown', onKey)
    }
  },
  { immediate: true },
)

onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKey)
  document.body.style.overflow = ''
})
</script>

<template>
  <Teleport to="body">
    <div
      v-if="open"
      class="fixed inset-0 z-[100] flex items-end sm:items-center justify-center p-0 sm:p-6"
    >
      <div class="absolute inset-0 bg-on-surface/40 backdrop-blur-[2px]" @click="emit('close')" />
      <div
        ref="panel"
        role="dialog"
        aria-modal="true"
        class="relative w-full bg-surface-white rounded-t-2xl sm:rounded-2xl shadow-2xl max-h-[92vh] flex flex-col"
        :class="width"
      >
        <header class="flex items-start justify-between gap-4 px-6 py-5 border-b border-border-subtle">
          <div class="min-w-0">
            <h2 class="text-headline-md font-bold truncate">{{ title }}</h2>
            <p v-if="subtitle" class="text-[13px] text-muted mt-1">{{ subtitle }}</p>
          </div>
          <button
            class="text-muted hover:text-on-surface transition-colors shrink-0"
            aria-label="Tutup"
            @click="emit('close')"
          >
            <span class="material-symbols-outlined">close</span>
          </button>
        </header>
        <div class="px-6 py-5 overflow-y-auto">
          <slot />
        </div>
        <footer v-if="$slots.footer" class="px-6 py-4 border-t border-border-subtle bg-surface-container-low rounded-b-2xl">
          <slot name="footer" />
        </footer>
      </div>
    </div>
  </Teleport>
</template>
