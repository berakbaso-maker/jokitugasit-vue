<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getRequest, listPayments, formatRupiah, CATEGORY_LABELS, STATUS_LABELS } from '../lib/api'
import { PAYMENT_KIND_LABELS } from '../lib/money'
import { barisPembayaran, labelKuitansi, nomorKuitansi, ringkasKuitansi } from '../lib/kuitansi'
import { pesanGalat } from '../lib/galat'

const route = useRoute()
const router = useRouter()

const request = ref(null)
const payments = ref([])
const loading = ref(true)
const errorMsg = ref('')

const ringkas = computed(() => ringkasKuitansi(request.value || {}, payments.value))
const baris = computed(() => barisPembayaran(payments.value))
const nomor = computed(() => nomorKuitansi(request.value?.order_no))

const tanggal = (nilai) => (nilai ? new Date(nilai).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' }) : '-')

async function muat() {
  loading.value = true
  errorMsg.value = ''
  try {
    const r = await getRequest(route.params.id)
    request.value = r
    payments.value = (await listPayments(r.id)) || []
  } catch (err) {
    errorMsg.value = pesanGalat(err, 'Gagal memuat kuitansi.')
  } finally {
    loading.value = false
  }
}

function cetak() {
  window.print()
}

onMounted(muat)
</script>

<template>
  <main id="konten-utama" tabindex="-1" class="bg-surface-container-lowest min-h-screen py-8 px-4 print:bg-white print:p-0">
    <div v-if="loading" class="max-w-3xl mx-auto text-center text-secondary py-16">Memuat kuitansi…</div>

    <div v-else-if="errorMsg" class="max-w-3xl mx-auto bg-error-container text-on-error-container rounded-xl p-6" role="alert">
      {{ errorMsg }}
    </div>

    <div v-else-if="request" class="max-w-3xl mx-auto">
      <!-- aksi, tidak ikut tercetak -->
      <div class="flex flex-wrap items-center justify-between gap-3 mb-4 print:hidden">
        <button class="inline-flex items-center gap-2 h-11 px-4 rounded-lg border border-border-subtle bg-surface-white font-label-bold text-label-bold" @click="router.back()">
          <span class="material-symbols-outlined text-[18px]">arrow_back</span> Kembali
        </button>
        <button class="inline-flex items-center gap-2 h-11 px-5 rounded-lg bg-accent-fill text-white font-label-bold text-label-bold" @click="cetak">
          <span class="material-symbols-outlined text-[18px]">print</span> Cetak / Simpan PDF
        </button>
      </div>

      <article class="bg-surface-white border border-border-subtle rounded-2xl p-6 sm:p-10 print:border-0 print:rounded-none print:p-0">
        <!-- kop -->
        <header class="flex flex-wrap items-start justify-between gap-4 pb-6 border-b border-border-subtle">
          <div>
            <p class="font-bold text-xl text-on-surface">jokitugasit<span class="text-electric-blue">.my.id</span></p>
            <p class="text-xs text-secondary mt-1">Bantuan teknis tugas IT &amp; pengembangan aplikasi</p>
            <p class="text-xs text-secondary">WhatsApp 0851-6633-7257 · jokitugasit.my.id</p>
          </div>
          <div class="text-right">
            <p class="text-[11px] tracking-wider text-secondary uppercase">Kuitansi</p>
            <p class="font-bold text-lg text-on-surface">{{ nomor }}</p>
            <p class="text-xs text-secondary">{{ tanggal(request.created_at) }}</p>
          </div>
        </header>

        <!-- identitas -->
        <section class="grid sm:grid-cols-2 gap-6 py-6 border-b border-border-subtle text-sm">
          <div>
            <p class="text-[11px] tracking-wider text-secondary uppercase mb-1">Ditagihkan kepada</p>
            <p class="font-bold text-on-surface">{{ request.customer_name }}</p>
            <p class="text-secondary">{{ request.whatsapp }}</p>
            <p v-if="request.campus" class="text-secondary">{{ request.campus }}</p>
          </div>
          <div class="sm:text-right">
            <p class="text-[11px] tracking-wider text-secondary uppercase mb-1">Status order</p>
            <p class="font-bold text-on-surface">{{ STATUS_LABELS[request.status] || request.status }}</p>
            <p class="text-secondary">Dibuat: {{ tanggal(request.created_at) }}</p>
          </div>
        </section>

        <!-- rincian -->
        <section class="py-6 border-b border-border-subtle">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-[11px] uppercase tracking-wider text-secondary">
                <th class="pb-2">Deskripsi</th>
                <th class="pb-2 text-right w-32">Jumlah</th>
              </tr>
            </thead>
            <tbody class="align-top">
              <tr>
                <td class="py-2">
                  <p class="font-semibold text-on-surface">{{ CATEGORY_LABELS[request.category] || request.category }}</p>
                  <p class="text-secondary text-xs mt-1 whitespace-pre-line">{{ request.description }}</p>
                </td>
                <td class="py-2 text-right text-on-surface tabular-nums">{{ formatRupiah(request.quote_amount) }}</td>
              </tr>
              <tr v-if="Number(request.discount_amount) > 0">
                <td class="py-1 text-secondary">Diskon</td>
                <td class="py-1 text-right text-secondary tabular-nums">− {{ formatRupiah(request.discount_amount) }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="border-t border-border-subtle">
                <td class="pt-3 font-bold text-on-surface">Total tagihan</td>
                <td class="pt-3 text-right font-bold text-on-surface tabular-nums">{{ formatRupiah(ringkas.total) }}</td>
              </tr>
              <tr>
                <td class="py-1 text-secondary">Sudah dibayar</td>
                <td class="py-1 text-right text-secondary tabular-nums">{{ formatRupiah(ringkas.dibayar) }}</td>
              </tr>
              <tr>
                <td class="py-1 font-bold" :class="ringkas.sisa > 0 ? 'text-urgency-red' : 'text-success-green'">Sisa</td>
                <td class="py-1 text-right font-bold tabular-nums" :class="ringkas.sisa > 0 ? 'text-urgency-red' : 'text-success-green'">{{ formatRupiah(ringkas.sisa) }}</td>
              </tr>
            </tfoot>
          </table>
        </section>

        <!-- riwayat pembayaran -->
        <section class="py-6">
          <p class="text-[11px] tracking-wider text-secondary uppercase mb-3">Riwayat pembayaran</p>
          <p v-if="!baris.length" class="text-sm text-secondary">Belum ada pembayaran tercatat.</p>
          <table v-else class="w-full text-sm">
            <thead>
              <tr class="text-left text-[11px] uppercase tracking-wider text-secondary">
                <th class="pb-2">Tanggal</th>
                <th class="pb-2">Jenis</th>
                <th class="pb-2">Catatan</th>
                <th class="pb-2 text-right">Nominal</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in baris" :key="p.id" class="border-t border-border-subtle">
                <td class="py-2 text-secondary">{{ tanggal(p.paid_at || p.created_at) }}</td>
                <td class="py-2 text-on-surface">{{ PAYMENT_KIND_LABELS[p.kind] || p.kind }}</td>
                <td class="py-2 text-secondary">{{ p.note || '-' }}</td>
                <td class="py-2 text-right text-on-surface tabular-nums">{{ formatRupiah(p.amount) }}</td>
              </tr>
            </tbody>
          </table>

          <p class="mt-5 inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-bold"
             :class="ringkas.lunas ? 'bg-success-green/15 text-success-green' : 'bg-surface-container-high text-on-surface-variant'">
            <span class="material-symbols-outlined text-[16px]">{{ ringkas.lunas ? 'verified' : 'pending' }}</span>
            {{ labelKuitansi(ringkas) }}
          </p>
        </section>

        <footer class="pt-6 border-t border-border-subtle text-xs text-secondary">
          <p>Kuitansi ini dibuat otomatis dari sistem jokitugasit.my.id dan sah tanpa tanda tangan basah.</p>
          <p class="mt-1">Pertanyaan: WhatsApp 0851-6633-7257 dengan menyebutkan {{ request.order_no }}.</p>
        </footer>
      </article>
    </div>
  </main>
</template>
