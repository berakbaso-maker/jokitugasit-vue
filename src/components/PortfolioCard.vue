<script setup>
/**
 * PortfolioCard — kartu proyek untuk grid portofolio.
 *
 * Dua varian:
 *   - 'wide' : kartu unggulan (gambar kiri, teks kanan) mulai md
 *   - 'grid' : kartu biasa (gambar atas, teks bawah)
 *
 * Seluruh kartu adalah satu tautan ke halaman detail, jadi tidak ada
 * elemen interaktif bersarang yang membingungkan keyboard.
 */
import { computed } from 'vue'
import ProjectMockup from './ProjectMockup.vue'
import { LABEL_KATEGORI } from '../lib/portfolio'

const props = defineProps({
  proyek: { type: Object, required: true },
  variant: { type: String, default: 'grid' },
})

const label = computed(() => LABEL_KATEGORI[props.proyek.category] || props.proyek.category)
const stackUtama = computed(() => props.proyek.stack.slice(0, 3))
const sisaStack = computed(() => Math.max(0, props.proyek.stack.length - 3))
</script>

<template>
  <RouterLink
    :to="`/portofolio/${proyek.slug}`"
    class="group flex flex-col overflow-hidden rounded-2xl border border-border-subtle bg-surface-white shadow-card transition-[transform,box-shadow] duration-200 hover:-translate-y-1 hover:shadow-card-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
    :class="variant === 'wide' ? 'md:flex-row' : ''"
  >
    <div :class="variant === 'wide' ? 'md:w-[46%] md:shrink-0' : ''">
      <ProjectMockup
        :gradient="proyek.mockup.gradient"
        :icon="proyek.mockup.icon"
        :variant="variant === 'wide' ? 'wide' : 'card'"
      />
    </div>

    <div class="flex flex-1 flex-col p-5">
      <div class="mb-2 flex flex-wrap items-center gap-2">
        <span
          class="rounded-full bg-primary-fixed px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-on-primary-fixed"
        >
          {{ label }}
        </span>
        <span class="text-xs font-semibold text-muted">{{ proyek.year }}</span>
      </div>

      <h3
        class="text-headline-md font-headline-md font-bold text-on-surface transition-colors group-hover:text-primary"
        :class="variant === 'wide' ? 'text-xl' : ''"
      >
        {{ proyek.title }}
      </h3>

      <p class="mt-1.5 line-clamp-2 text-sm text-secondary">{{ proyek.tagline }}</p>

      <!-- metrik utama: satu angka yang bikin orang berhenti -->
      <p v-if="proyek.result?.metrics?.length" class="mt-3 text-sm font-semibold text-primary">
        {{ proyek.result.metrics[0].label }}:
        <span class="text-on-surface">{{ proyek.result.metrics[0].value }}</span>
      </p>

      <div class="mt-auto flex flex-wrap items-center gap-1.5 pt-4">
        <span
          v-for="s in stackUtama"
          :key="s"
          class="rounded-md bg-surface-container px-2 py-1 text-[11px] font-semibold text-on-surface-variant"
        >
          {{ s }}
        </span>
        <span v-if="sisaStack" class="text-[11px] font-semibold text-muted">+{{ sisaStack }}</span>
      </div>
    </div>
  </RouterLink>
</template>
