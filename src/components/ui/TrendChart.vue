<script setup>
/**
 * TrendChart — grafik batang/garis SVG tanpa dependency.
 * Data: [{ date, leads, revenue }] dari RPC get_internal_trends.
 */
import { computed, ref } from 'vue'

const props = defineProps({
  series: { type: Array, default: () => [] },
  metric: { type: String, default: 'leads' }, // leads | revenue
  height: { type: Number, default: 160 },
  label: { type: String, default: '' },
  format: { type: String, default: 'number' },
})

const hover = ref(null)

const values = computed(() => props.series.map(d => Number(d[props.metric]) || 0))
const max = computed(() => Math.max(1, ...values.value))
const total = computed(() => values.value.reduce((a, b) => a + b, 0))

const nf = new Intl.NumberFormat('id-ID')
const fmt = (n) => props.format === 'currency' ? 'Rp ' + nf.format(Math.round(n)) : nf.format(n)

const bars = computed(() => {
  const n = props.series.length || 1
  const gap = n > 20 ? 1 : 2
  const w = 100 / n
  return props.series.map((d, i) => {
    const v = Number(d[props.metric]) || 0
    const h = (v / max.value) * 100
    return {
      x: i * w,
      w: Math.max(0.6, w - gap),
      h,
      v,
      date: d.date,
    }
  })
})

const niceDate = (d) => {
  if (!d) return ''
  const dt = new Date(d)
  return dt.toLocaleDateString('id-ID', { day: '2-digit', month: 'short' })
}
</script>

<template>
  <div class="bg-surface-white border border-border-subtle rounded-2xl p-5 shadow-card">
    <div class="flex items-baseline justify-between gap-3 mb-1">
      <p class="text-label-sm text-secondary uppercase tracking-wider">{{ label }}</p>
      <p class="text-[13px] text-muted tabular-nums">{{ fmt(total) }} total</p>
    </div>

    <div v-if="!series.length" class="h-[160px] grid place-items-center text-[13px] text-muted">
      Belum ada data pada periode ini.
    </div>

    <div v-else class="relative" :style="{ height: height + 'px' }">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" class="w-full h-full overflow-visible">
        <line v-for="p in [25, 50, 75]" :key="p" x1="0" :y1="p" x2="100" :y2="p"
              stroke="#E2E8F0" stroke-width="0.4" vector-effect="non-scaling-stroke" />
        <rect
          v-for="(b, i) in bars"
          :key="i"
          :x="b.x" :y="100 - b.h" :width="b.w" :height="Math.max(b.h, 0.5)"
          rx="0.4"
          class="transition-opacity"
          :class="hover === i ? 'fill-primary' : 'fill-primary/70'"
          @mouseenter="hover = i"
          @mouseleave="hover = null"
        />
      </svg>
      <div
        v-if="hover !== null"
        class="absolute -top-1 pointer-events-none bg-on-surface text-white text-[11px] px-2 py-1 rounded-md whitespace-nowrap -translate-x-1/2 z-10"
        :style="{ left: ((hover + 0.5) / series.length) * 100 + '%' }"
      >
        {{ niceDate(bars[hover].date) }} · {{ fmt(bars[hover].v) }}
      </div>
    </div>

    <div v-if="series.length" class="flex justify-between mt-2 text-[10px] text-muted">
      <span>{{ niceDate(series[0]?.date) }}</span>
      <span>{{ niceDate(series[series.length - 1]?.date) }}</span>
    </div>
  </div>
</template>
