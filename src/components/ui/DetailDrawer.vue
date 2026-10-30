<script setup>
/**
 * DetailDrawer — panel samping untuk detail record.
 */
import { onBeforeUnmount, onMounted } from 'vue'

defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  width: { type: String, default: 'max-w-lg' },
})
const emit = defineEmits(['close'])

function onKey(e) { if (e.key === 'Escape') emit('close') }

onMounted(() => document.addEventListener('keydown', onKey))
onBeforeUnmount(() => document.removeEventListener('keydown', onKey))
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition-opacity duration-200"
      leave-active-class="transition-opacity duration-150"
      enter-from-class="opacity-0" leave-to-class="opacity-0"
    >
      <div v-if="open" class="fixed inset-0 z-[95]">
        <div class="absolute inset-0 bg-on-surface/30 backdrop-blur-[1px]" @click="emit('close')" />
        <aside
          class="absolute right-0 inset-y-0 w-full bg-surface-white shadow-2xl flex flex-col"
          :class="width"
        >
          <header class="flex items-start justify-between gap-4 px-5 py-4 border-b border-border-subtle">
            <div class="min-w-0">
              <h2 class="text-headline-md font-bold truncate">{{ title }}</h2>
              <p v-if="subtitle" class="text-[13px] text-muted mt-0.5 truncate">{{ subtitle }}</p>
            </div>
            <button class="text-muted hover:text-on-surface shrink-0" aria-label="Tutup" @click="emit('close')">
              <span class="material-symbols-outlined">close</span>
            </button>
          </header>
          <div class="flex-1 overflow-y-auto px-5 py-5">
            <slot />
          </div>
          <footer v-if="$slots.footer" class="px-5 py-4 border-t border-border-subtle bg-surface-container-low">
            <slot name="footer" />
          </footer>
        </aside>
      </div>
    </Transition>
  </Teleport>
</template>
