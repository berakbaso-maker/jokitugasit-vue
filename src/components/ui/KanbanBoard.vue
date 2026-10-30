<script setup>
/**
 * KanbanBoard — drag & drop native HTML5, tanpa dependency.
 * Kolom: { key, label, tone? }
 * Item wajib punya prop kunci (default 'id') dan field status.
 */
import { computed, ref } from 'vue'

const props = defineProps({
  columns: { type: Array, required: true },
  items: { type: Array, default: () => [] },
  statusKey: { type: String, default: 'stage' },
  itemKey: { type: String, default: 'id' },
  titleKey: { type: String, default: 'display_name' },
  subtitleKey: { type: String, default: 'organization' },
})

const emit = defineEmits(['move', 'open'])

const draggingId = ref(null)
const overColumn = ref('')

const grouped = computed(() => {
  const g = {}
  for (const c of props.columns) g[c.key] = []
  for (const it of props.items) {
    const k = it[props.statusKey]
    if (g[k]) g[k].push(it)
  }
  return g
})

function onDragStart(item, e) {
  draggingId.value = item[props.itemKey]
  e.dataTransfer.effectAllowed = 'move'
  e.dataTransfer.setData('text/plain', String(item[props.itemKey]))
}

function onDrop(colKey, e) {
  e.preventDefault()
  overColumn.value = ''
  const id = draggingId.value
  draggingId.value = null
  if (!id) return
  const item = props.items.find(i => String(i[props.itemKey]) === String(id))
  if (!item || item[props.statusKey] === colKey) return
  emit('move', { item, from: item[props.statusKey], to: colKey })
}
</script>

<template>
  <div class="flex gap-4 overflow-x-auto pb-4 -mx-1 px-1">
    <section
      v-for="col in columns"
      :key="col.key"
      class="w-[290px] shrink-0 flex flex-col rounded-2xl bg-surface-container-low border transition-colors"
      :class="overColumn === col.key ? 'border-primary ring-2 ring-primary/20' : 'border-border-subtle'"
      @dragover.prevent="overColumn = col.key"
      @dragleave="overColumn = ''"
      @drop="onDrop(col.key, $event)"
    >
      <header class="flex items-center justify-between px-4 py-3 border-b border-border-subtle">
        <div class="flex items-center gap-2 min-w-0">
          <span class="w-2 h-2 rounded-full shrink-0" :class="col.dot || 'bg-primary'" />
          <h3 class="font-label-bold text-[12px] uppercase tracking-wider text-secondary truncate">
            {{ col.label }}
          </h3>
        </div>
        <span class="text-[11px] font-semibold text-muted tabular-nums">{{ grouped[col.key].length }}</span>
      </header>

      <div class="p-2.5 space-y-2.5 min-h-[120px] max-h-[calc(100vh-320px)] overflow-y-auto">
        <article
          v-for="item in grouped[col.key]"
          :key="item[itemKey]"
          draggable="true"
          class="bg-surface-white rounded-xl border border-border-subtle p-3 shadow-card cursor-grab active:cursor-grabbing hover:shadow-card-hover transition-shadow"
          :class="draggingId === item[itemKey] ? 'opacity-40' : ''"
          @dragstart="onDragStart(item, $event)"
          @dragend="draggingId = null"
          @click="emit('open', item)"
        >
          <p class="font-semibold text-[14px] leading-snug line-clamp-2">
            {{ item[titleKey] || '—' }}
          </p>
          <p v-if="item[subtitleKey]" class="text-[12px] text-muted mt-1 truncate">
            {{ item[subtitleKey] }}
          </p>
          <div class="mt-2 flex items-center gap-2 flex-wrap">
            <slot name="item-meta" :item="item" />
          </div>
        </article>

        <p v-if="!grouped[col.key].length" class="text-center text-[12px] text-muted py-6">
          Kosong
        </p>
      </div>
    </section>
  </div>
</template>
