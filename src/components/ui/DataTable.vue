<script setup>
/**
 * DataTable — tabel data dengan pencarian, sort, dan slot kolom.
 *
 * Visual mengikuti tabel ProspectsView milik project utama:
 *   wrapper : bg-surface-white rounded-xl border border-border-subtle overflow-hidden
 *   thead   : bg-surface-container-low text-left, th px-4 py-3 font-bold text-on-surface-variant
 *   tr      : border-t border-border-subtle
 * Sengaja TIDAK membungkus dirinya dalam kartu ganda — pemanggil yang
 * menyediakan wrapper bila perlu.
 *
 * Kolom: { key, label, sortable?, align?, width? }
 */
import { computed, ref } from 'vue'

const props = defineProps({
  columns: { type: Array, required: true },
  rows: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  searchable: { type: Boolean, default: true },
  searchPlaceholder: { type: String, default: 'Cari…' },
  rowKey: { type: String, default: 'id' },
  emptyText: { type: String, default: 'Belum ada data.' },
  pageSize: { type: Number, default: 25 },
  bordered: { type: Boolean, default: true },
})

const emit = defineEmits(['row-click'])

const q = ref('')
const sortKey = ref('')
const sortDir = ref('asc')
const page = ref(1)

const filtered = computed(() => {
  const term = q.value.trim().toLowerCase()
  if (!term) return props.rows
  return props.rows.filter(r =>
    props.columns.some(c => String(r[c.key] ?? '').toLowerCase().includes(term))
  )
})

const sorted = computed(() => {
  if (!sortKey.value) return filtered.value
  const k = sortKey.value
  const dir = sortDir.value === 'asc' ? 1 : -1
  return [...filtered.value].sort((a, b) => {
    const av = a[k], bv = b[k]
    if (av == null && bv == null) return 0
    if (av == null) return 1
    if (bv == null) return -1
    if (typeof av === 'number' && typeof bv === 'number') return (av - bv) * dir
    return String(av).localeCompare(String(bv), 'id') * dir
  })
})

const totalPages = computed(() => Math.max(1, Math.ceil(sorted.value.length / props.pageSize)))
const paged = computed(() => {
  const start = (page.value - 1) * props.pageSize
  return sorted.value.slice(start, start + props.pageSize)
})

function toggleSort(col) {
  if (!col.sortable) return
  if (sortKey.value === col.key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortKey.value = col.key
    sortDir.value = 'asc'
  }
  page.value = 1
}

function setPage(n) {
  page.value = Math.min(Math.max(1, n), totalPages.value)
}
</script>

<template>
  <div>
    <div v-if="searchable" class="flex items-center gap-3 mb-3">
      <div class="relative w-full sm:w-72">
        <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-[18px] text-on-surface-variant pointer-events-none">search</span>
        <input
          v-model="q"
          type="search"
          :placeholder="searchPlaceholder"
          class="w-full rounded-xl border border-outline-variant bg-surface-white pl-10 pr-4 py-2.5 text-sm
                 focus:outline-none focus:ring-2 focus:ring-electric-blue/40"
          @input="page = 1"
        />
      </div>
      <span class="text-label-sm text-on-surface-variant tabular-nums whitespace-nowrap ml-auto">
        {{ filtered.length }} baris
      </span>
    </div>

    <div :class="bordered ? 'bg-surface-white border border-border-subtle rounded-xl overflow-hidden' : ''">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-surface-container-low text-left border-b border-border-subtle">
            <tr class="text-on-surface-variant">
              <th
                v-for="c in columns"
                :key="c.key"
                class="px-4 py-3 font-bold whitespace-nowrap"
                :class="[{ 'cursor-pointer select-none hover:text-electric-blue': c.sortable },
                         c.align === 'right' ? 'text-right' : '']"
                :style="c.width ? { width: c.width } : {}"
                @click="toggleSort(c)"
              >
                {{ c.label }}
                <span v-if="sortKey === c.key" class="material-symbols-outlined text-[14px] align-middle">
                  {{ sortDir === 'asc' ? 'arrow_upward' : 'arrow_downward' }}
                </span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loading">
              <td :colspan="columns.length" class="px-4 py-10 text-center text-on-surface-variant">
                <span class="material-symbols-outlined animate-spin align-middle">progress_activity</span>
                Memuat…
              </td>
            </tr>
            <tr v-else-if="!paged.length">
              <td :colspan="columns.length" class="px-4 py-10 text-center text-on-surface-variant">{{ emptyText }}</td>
            </tr>
            <tr
              v-for="(r, i) in paged"
              v-else
              :key="r[rowKey] ?? i"
              class="border-t border-border-subtle hover:bg-surface-container-low/60 transition-colors cursor-pointer"
              @click="emit('row-click', r)"
            >
              <td
                v-for="c in columns"
                :key="c.key"
                class="px-4 py-3 align-middle"
                :class="c.align === 'right' ? 'text-right tabular-nums' : ''"
              >
                <slot :name="`cell-${c.key}`" :row="r" :value="r[c.key]">
                  {{ r[c.key] ?? '—' }}
                </slot>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="totalPages > 1" class="flex items-center justify-between px-4 py-3 border-t border-border-subtle">
        <span class="text-label-sm text-on-surface-variant">Halaman {{ page }} dari {{ totalPages }}</span>
        <div class="flex gap-1">
          <button
            class="p-1.5 rounded-lg border border-outline-variant hover:bg-surface-container-low disabled:opacity-40"
            :disabled="page === 1"
            aria-label="Halaman sebelumnya"
            @click="setPage(page - 1)"
          >
            <span class="material-symbols-outlined text-[18px]">chevron_left</span>
          </button>
          <button
            class="p-1.5 rounded-lg border border-outline-variant hover:bg-surface-container-low disabled:opacity-40"
            :disabled="page === totalPages"
            aria-label="Halaman berikutnya"
            @click="setPage(page + 1)"
          >
            <span class="material-symbols-outlined text-[18px]">chevron_right</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
