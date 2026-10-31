<script setup>
/**
 * ProjectMockup — ilustrasi "tangkapan layar" abstrak untuk kartu portofolio.
 *
 * SENGAJA bukan screenshot asli: ini mockup dekoratif dari blok UI sederhana,
 * supaya tidak menampilkan data atau wajah palsu.
 *
 * Bentuknya BERBEDA per jenis proyek (lihat prop `bentuk`): proyek mobile
 * tampil sebagai bingkai HP, debug sebagai terminal error, database sebagai
 * skema tabel, dan seterusnya. Tujuannya supaya grid kartu tidak terasa
 * seperti satu template yang diulang -- masalah nyata pada versi pertama
 * yang memakai satu bentuk jendela aplikasi untuk semua kategori.
 *
 * Semua elemen SVG diberi aria-hidden + role="presentation"; teks alternatif
 * disediakan lewat aria-label pada pembungkusnya.
 */
import { computed } from 'vue'
import { pakaiTema } from '../lib/tema'

const props = defineProps({
  gradient: { type: Array, default: () => ['#2563EB', '#1E3A8A'] },
  icon: { type: String, default: 'widgets' },
  /** 'wide' untuk kartu unggulan, 'card' untuk grid biasa. */
  variant: { type: String, default: 'card' },
  /**
   * Bentuk ilustrasi, diisi `category` proyek:
   * web | mobile | desktop | database | ai | skripsi | debug | design |
   * tugas_kuliah. Nilai tak dikenal jatuh ke bentuk 'web'.
   */
  bentuk: { type: String, default: 'web' },
})

// id unik supaya gradien antar-instance tidak saling menimpa
const uid = `mk${Math.random().toString(36).slice(2, 9)}`

const BENTUK_VALID = [
  'web',
  'mobile',
  'desktop',
  'database',
  'ai',
  'skripsi',
  'debug',
  'design',
  'tugas_kuliah',
]

const bentukAktif = computed(() =>
  BENTUK_VALID.includes(props.bentuk) ? props.bentuk : 'web',
)

// Warna netral yang dipakai semua varian supaya tetap satu bahasa visual.
// Palet netral ilustrasi. Di mode gelap dibalik supaya panel "layar" tetap
// terbaca sebagai panel, bukan silau putih di tengah kanvas gelap.
// Urutan kontras terhadap panel dipertahankan di kedua tema.
const { isDark } = pakaiTema()
const PANEL = computed(() => (isDark.value ? '#1E293B' : '#FFFFFF'))
const NETRAL = computed(() => (isDark.value ? '#475569' : '#E2E8F0'))
const NETRAL_TERANG = computed(() => (isDark.value ? '#334155' : '#F1F5F9'))
const NETRAL_MUDA = computed(() => (isDark.value ? '#0F172A' : '#F8FAFC'))
const NETRAL_GELAP = computed(() => (isDark.value ? '#64748B' : '#CBD5E1'))

// Tinggi batang grafik AI -- statis (bukan acak) supaya render stabil
// dan tidak berubah tiap kali komponen di-mount ulang.
const BATANG_AI = [18, 26, 22, 34, 30, 42, 38, 50, 46, 58]

// Baris log terminal untuk bentuk debug.
const BARIS_LOG = [
  { w: 44, warna: '#F87171' },
  { w: 68, warna: '#CBD5E1' },
  { w: 52, warna: '#FBBF24' },
  { w: 74, warna: '#CBD5E1' },
  { w: 38, warna: '#4ADE80' },
  { w: 60, warna: '#CBD5E1' },
]
</script>

<template>
  <div
    class="relative overflow-hidden"
    :class="variant === 'wide' ? 'aspect-[16/9]' : 'aspect-[16/10]'"
    role="img"
    :aria-label="`Ilustrasi antarmuka proyek kategori ${bentukAktif.replace('_', ' ')}`"
  >
    <svg
      class="h-full w-full"
      viewBox="0 0 320 200"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
      role="presentation"
    >
      <defs>
        <linearGradient :id="uid" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" :stop-color="gradient[0]" />
          <stop offset="100%" :stop-color="gradient[1]" />
        </linearGradient>
      </defs>

      <!-- latar gradien + lingkaran dekoratif (sama untuk semua bentuk) -->
      <rect width="320" height="200" :fill="`url(#${uid})`" />
      <circle cx="292" cy="24" r="62" fill="#ffffff" opacity="0.07" />
      <circle cx="30" cy="184" r="50" fill="#ffffff" opacity="0.06" />

      <!-- ============ WEB: jendela browser ============ -->
      <g v-if="bentukAktif === 'web'" transform="translate(34 30)">
        <rect width="252" height="150" rx="8" :fill="PANEL" opacity="0.97" />
        <rect width="252" height="22" rx="8" :fill="NETRAL_TERANG" />
        <rect y="14" width="252" height="8" :fill="NETRAL_TERANG" />
        <circle cx="13" cy="11" r="2.8" :fill="NETRAL_GELAP" />
        <circle cx="23" cy="11" r="2.8" :fill="NETRAL_GELAP" />
        <circle cx="33" cy="11" r="2.8" :fill="NETRAL_GELAP" />
        <rect x="46" y="7" width="150" height="8" rx="4" :fill="NETRAL" />
        <g transform="translate(14 34)">
          <rect width="98" height="9" rx="4.5" :fill="gradient[0]" opacity="0.9" />
          <rect y="16" width="132" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect y="27" width="112" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect y="40" width="54" height="16" rx="8" :fill="gradient[0]" />
          <rect x="60" y="40" width="42" height="16" rx="8" :fill="NETRAL" />
        </g>
        <g transform="translate(14 104)">
          <rect width="70" height="34" rx="5" :fill="NETRAL_MUDA" />
          <rect x="7" y="7" width="16" height="16" rx="4" :fill="gradient[0]" opacity="0.7" />
          <rect x="7" y="27" width="42" height="3.5" rx="1.75" :fill="NETRAL_GELAP" />
          <rect x="88" width="70" height="34" rx="5" :fill="NETRAL_MUDA" />
          <rect x="95" y="7" width="16" height="16" rx="4" :fill="gradient[0]" opacity="0.5" />
          <rect x="95" y="27" width="42" height="3.5" rx="1.75" :fill="NETRAL_GELAP" />
          <rect x="176" width="70" height="34" rx="5" :fill="NETRAL_MUDA" />
          <rect x="183" y="7" width="16" height="16" rx="4" :fill="gradient[0]" opacity="0.35" />
          <rect x="183" y="27" width="42" height="3.5" rx="1.75" :fill="NETRAL_GELAP" />
        </g>
      </g>

      <!-- ============ MOBILE: bingkai HP ============ -->
      <g v-else-if="bentukAktif === 'mobile'" transform="translate(112 18)">
        <rect width="96" height="166" rx="14" :fill="PANEL" opacity="0.97" />
        <rect x="34" y="6" width="28" height="5" rx="2.5" :fill="NETRAL" />
        <g transform="translate(10 20)">
          <rect width="46" height="7" rx="3.5" :fill="gradient[0]" opacity="0.9" />
          <circle cx="70" cy="3.5" r="7" :fill="NETRAL_TERANG" />
        </g>
        <g transform="translate(10 36)">
          <rect width="76" height="44" rx="7" :fill="gradient[0]" opacity="0.16" />
          <rect x="8" y="9" width="34" height="5" rx="2.5" :fill="gradient[0]" opacity="0.8" />
          <rect x="8" y="20" width="52" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="8" y="30" width="26" height="8" rx="4" :fill="gradient[0]" />
        </g>
        <g transform="translate(10 88)">
          <rect width="76" height="16" rx="5" :fill="NETRAL_MUDA" />
          <circle cx="10" cy="8" r="4.5" :fill="gradient[0]" opacity="0.5" />
          <rect x="20" y="6" width="34" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect y="22" width="76" height="16" rx="5" :fill="NETRAL_MUDA" />
          <circle cx="10" cy="30" r="4.5" :fill="gradient[0]" opacity="0.35" />
          <rect x="20" y="28" width="42" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect y="44" width="76" height="16" rx="5" :fill="NETRAL_MUDA" />
          <circle cx="10" cy="52" r="4.5" :fill="gradient[0]" opacity="0.25" />
          <rect x="20" y="50" width="30" height="4" rx="2" :fill="NETRAL_GELAP" />
        </g>
        <g transform="translate(10 142)">
          <rect width="76" height="1" :fill="NETRAL" />
          <circle cx="12" cy="10" r="4" :fill="gradient[0]" />
          <circle cx="32" cy="10" r="4" :fill="NETRAL_GELAP" />
          <circle cx="52" cy="10" r="4" :fill="NETRAL_GELAP" />
          <circle cx="72" cy="10" r="4" :fill="NETRAL_GELAP" />
        </g>
      </g>

      <!-- ============ DESKTOP: jendela app + sidebar ============ -->
      <g v-else-if="bentukAktif === 'desktop'" transform="translate(36 34)">
        <rect width="248" height="142" rx="7" :fill="PANEL" opacity="0.97" />
        <rect width="248" height="18" rx="7" :fill="NETRAL_TERANG" />
        <rect y="11" width="248" height="7" :fill="NETRAL_TERANG" />
        <circle cx="12" cy="9" r="3" :fill="gradient[0]" opacity="0.8" />
        <rect x="24" y="6.5" width="22" height="5" rx="2.5" :fill="NETRAL_GELAP" />
        <rect x="52" y="6.5" width="18" height="5" rx="2.5" :fill="NETRAL_GELAP" />
        <rect x="76" y="6.5" width="26" height="5" rx="2.5" :fill="NETRAL_GELAP" />
        <g transform="translate(0 18)">
          <rect width="248" height="22" :fill="NETRAL_MUDA" />
          <rect x="10" y="7" width="30" height="8" rx="4" :fill="gradient[0]" />
          <rect x="46" y="7" width="22" height="8" rx="4" :fill="NETRAL" />
          <rect x="74" y="7" width="22" height="8" rx="4" :fill="NETRAL" />
        </g>
        <g transform="translate(0 40)">
          <rect width="62" height="102" :fill="NETRAL_MUDA" />
          <rect x="9" y="12" width="40" height="5" rx="2.5" :fill="gradient[0]" opacity="0.85" />
          <rect x="9" y="26" width="30" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect x="9" y="40" width="36" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect x="9" y="54" width="24" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect x="9" y="68" width="32" height="5" rx="2.5" :fill="NETRAL_GELAP" />
        </g>
        <g transform="translate(72 48)">
          <rect width="166" height="18" rx="3" :fill="NETRAL_TERANG" />
          <rect x="8" y="6.5" width="30" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect x="48" y="6.5" width="34" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect x="92" y="6.5" width="26" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect y="24" width="166" height="14" rx="3" :fill="PANEL" />
          <rect x="8" y="29" width="38" height="4" rx="2" :fill="gradient[0]" opacity="0.55" />
          <rect x="56" y="29" width="28" height="4" rx="2" :fill="NETRAL" />
          <rect y="42" width="166" height="14" rx="3" :fill="NETRAL_MUDA" />
          <rect x="8" y="47" width="30" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="56" y="47" width="34" height="4" rx="2" :fill="NETRAL" />
          <rect y="60" width="166" height="14" rx="3" :fill="PANEL" />
          <rect x="8" y="65" width="34" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="56" y="65" width="24" height="4" rx="2" :fill="NETRAL" />
          <rect y="78" width="166" height="14" rx="3" :fill="NETRAL_MUDA" />
          <rect x="8" y="83" width="40" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="56" y="83" width="30" height="4" rx="2" :fill="NETRAL" />
        </g>
      </g>

      <!-- ============ DATABASE: skema tabel + relasi ============ -->
      <g v-else-if="bentukAktif === 'database'" transform="translate(26 32)">
        <rect width="268" height="146" rx="8" :fill="PANEL" opacity="0.97" />
        <g transform="translate(14 14)">
          <rect width="104" height="62" rx="5" :fill="NETRAL_MUDA" :stroke="NETRAL" />
          <rect width="104" height="16" rx="5" :fill="gradient[0]" opacity="0.9" />
          <rect x="8" y="5.5" width="34" height="5" rx="2.5" fill="#ffffff" opacity="0.9" />
          <rect x="8" y="24" width="44" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="8" y="35" width="36" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="8" y="46" width="50" height="4" rx="2" :fill="NETRAL_GELAP" />
        </g>
        <g transform="translate(150 62)">
          <rect width="104" height="62" rx="5" :fill="NETRAL_MUDA" :stroke="NETRAL" />
          <rect width="104" height="16" rx="5" :fill="gradient[0]" opacity="0.55" />
          <rect x="8" y="5.5" width="40" height="5" rx="2.5" fill="#ffffff" opacity="0.9" />
          <rect x="8" y="24" width="38" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="8" y="35" width="48" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="8" y="46" width="30" height="4" rx="2" :fill="NETRAL_GELAP" />
        </g>
        <path
          d="M118 45 C 138 45, 138 93, 150 93"
          fill="none"
          :stroke="gradient[0]"
          stroke-width="1.6"
          stroke-dasharray="4 3"
          opacity="0.7"
        />
        <circle cx="118" cy="45" r="2.6" :fill="gradient[0]" />
        <circle cx="150" cy="93" r="2.6" :fill="gradient[0]" />
        <g transform="translate(14 88)">
          <rect width="80" height="44" rx="5" :fill="NETRAL_MUDA" :stroke="NETRAL" />
          <rect width="80" height="13" rx="5" :fill="NETRAL_TERANG" />
          <rect x="7" y="4.5" width="24" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="7" y="20" width="30" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="7" y="30" width="22" height="4" rx="2" :fill="NETRAL_GELAP" />
        </g>
      </g>

      <!-- ============ AI: grafik tren + node ============ -->
      <g v-else-if="bentukAktif === 'ai'" transform="translate(28 30)">
        <rect width="264" height="150" rx="8" :fill="PANEL" opacity="0.97" />
        <rect x="14" y="14" width="60" height="6" rx="3" :fill="gradient[0]" opacity="0.85" />
        <rect x="14" y="26" width="38" height="4" rx="2" :fill="NETRAL_GELAP" />
        <g transform="translate(14 40)">
          <rect width="236" height="72" rx="5" :fill="NETRAL_MUDA" />
          <line x1="8" y1="18" x2="228" y2="18" :stroke="NETRAL" stroke-width="0.8" />
          <line x1="8" y1="36" x2="228" y2="36" :stroke="NETRAL" stroke-width="0.8" />
          <line x1="8" y1="54" x2="228" y2="54" :stroke="NETRAL" stroke-width="0.8" />
          <rect
            v-for="(tinggi, i) in BATANG_AI"
            :key="i"
            :x="10 + i * 22"
            :y="64 - tinggi"
            width="12"
            :height="tinggi"
            rx="2.5"
            :fill="gradient[0]"
            :opacity="0.35 + i * 0.06"
          />
        </g>
        <g transform="translate(14 120)">
          <circle cx="10" cy="10" r="5" :fill="gradient[0]" opacity="0.8" />
          <circle cx="40" cy="4" r="4" :fill="gradient[0]" opacity="0.55" />
          <circle cx="40" cy="16" r="4" :fill="gradient[0]" opacity="0.55" />
          <circle cx="70" cy="10" r="5" :fill="gradient[0]" opacity="0.4" />
          <line x1="15" y1="10" x2="36" y2="5" :stroke="gradient[0]" stroke-width="1" opacity="0.5" />
          <line x1="15" y1="10" x2="36" y2="16" :stroke="gradient[0]" stroke-width="1" opacity="0.5" />
          <line x1="44" y1="5" x2="65" y2="9" :stroke="gradient[0]" stroke-width="1" opacity="0.5" />
          <line x1="44" y1="16" x2="65" y2="11" :stroke="gradient[0]" stroke-width="1" opacity="0.5" />
          <rect x="96" width="60" height="22" rx="4" :fill="NETRAL_MUDA" />
          <rect x="103" y="6" width="24" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="103" y="13" width="34" height="5" rx="2.5" :fill="gradient[0]" opacity="0.7" />
          <rect x="164" width="60" height="22" rx="4" :fill="NETRAL_MUDA" />
          <rect x="171" y="6" width="20" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="171" y="13" width="30" height="5" rx="2.5" :fill="NETRAL_GELAP" />
        </g>
      </g>

      <!-- ============ SKRIPSI: dokumen bertumpuk ============ -->
      <g v-else-if="bentukAktif === 'skripsi'" transform="translate(46 24)">
        <rect x="16" y="8" width="196" height="152" rx="6" :fill="PANEL" opacity="0.55" />
        <rect x="8" y="4" width="196" height="152" rx="6" :fill="PANEL" opacity="0.75" />
        <rect width="196" height="152" rx="6" :fill="PANEL" opacity="0.98" />
        <rect x="52" y="16" width="92" height="7" rx="3.5" :fill="gradient[0]" opacity="0.9" />
        <rect x="66" y="29" width="64" height="4" rx="2" :fill="NETRAL_GELAP" />
        <line x1="30" y1="42" x2="166" y2="42" :stroke="NETRAL" stroke-width="1" />
        <g transform="translate(30 52)">
          <rect width="136" height="4" rx="2" :fill="NETRAL" />
          <rect y="9" width="136" height="4" rx="2" :fill="NETRAL" />
          <rect y="18" width="112" height="4" rx="2" :fill="NETRAL" />
          <rect y="31" width="136" height="4" rx="2" :fill="NETRAL" />
          <rect y="40" width="128" height="4" rx="2" :fill="NETRAL" />
          <rect y="49" width="96" height="4" rx="2" :fill="NETRAL" />
          <rect y="62" width="136" height="22" rx="3" :fill="gradient[0]" opacity="0.12" />
          <rect x="7" y="69" width="120" height="4" rx="2" :fill="gradient[0]" opacity="0.45" />
          <rect x="7" y="77" width="98" height="4" rx="2" :fill="gradient[0]" opacity="0.3" />
        </g>
      </g>

      <!-- ============ DEBUG: terminal + log error ============ -->
      <g v-else-if="bentukAktif === 'debug'" transform="translate(30 32)">
        <rect width="260" height="146" rx="8" fill="#0F172A" opacity="0.97" />
        <rect width="260" height="18" rx="8" fill="#1E293B" />
        <rect y="11" width="260" height="7" fill="#1E293B" />
        <circle cx="12" cy="9" r="3" fill="#F87171" />
        <circle cx="22" cy="9" r="3" fill="#FBBF24" />
        <circle cx="32" cy="9" r="3" fill="#4ADE80" />
        <rect x="46" y="6.5" width="44" height="5" rx="2.5" fill="#334155" />
        <g transform="translate(14 32)">
          <g v-for="(baris, i) in BARIS_LOG" :key="i" :transform="`translate(0 ${i * 15})`">
            <circle cx="3" cy="2.5" r="2.4" :fill="baris.warna" opacity="0.9" />
            <rect x="12" :width="baris.w" height="5" rx="2.5" :fill="baris.warna" opacity="0.55" />
            <rect :x="baris.w + 20" width="56" height="5" rx="2.5" fill="#475569" />
          </g>
        </g>
        <rect x="14" y="124" width="7" height="10" rx="1" fill="#4ADE80" opacity="0.85" />
        <g transform="translate(196 118)">
          <rect width="50" height="18" rx="9" fill="#4ADE80" opacity="0.16" />
          <circle cx="12" cy="9" r="3.4" fill="#4ADE80" />
          <rect x="20" y="6.5" width="22" height="5" rx="2.5" fill="#4ADE80" opacity="0.7" />
        </g>
      </g>

      <!-- ============ DESIGN: artboard wireframe + palet ============ -->
      <g v-else-if="bentukAktif === 'design'" transform="translate(28 30)">
        <rect width="264" height="150" rx="8" :fill="PANEL" opacity="0.97" />
        <rect x="12" y="12" width="24" height="24" rx="6" :fill="gradient[0]" opacity="0.85" />
        <rect x="42" y="12" width="24" height="24" rx="6" :fill="NETRAL_TERANG" />
        <rect x="72" y="12" width="24" height="24" rx="6" :fill="NETRAL_TERANG" />
        <rect x="102" y="12" width="24" height="24" rx="6" :fill="NETRAL_TERANG" />
        <g transform="translate(12 46)">
          <rect
            width="160"
            height="90"
            rx="4"
            :fill="NETRAL_MUDA"
            :stroke="gradient[0]"
            stroke-width="1"
            stroke-dasharray="3 2"
          />
          <rect x="10" y="10" width="140" height="20" rx="3" :fill="NETRAL" />
          <rect x="10" y="38" width="66" height="42" rx="3" :fill="gradient[0]" opacity="0.2" />
          <rect x="84" y="38" width="66" height="42" rx="3" :fill="gradient[0]" opacity="0.12" />
          <rect x="-2.5" y="-2.5" width="5" height="5" :fill="PANEL" :stroke="gradient[0]" />
          <rect x="157.5" y="-2.5" width="5" height="5" :fill="PANEL" :stroke="gradient[0]" />
          <rect x="-2.5" y="87.5" width="5" height="5" :fill="PANEL" :stroke="gradient[0]" />
          <rect x="157.5" y="87.5" width="5" height="5" :fill="PANEL" :stroke="gradient[0]" />
        </g>
        <g transform="translate(184 46)">
          <rect width="68" height="90" rx="4" :fill="NETRAL_MUDA" />
          <rect x="8" y="8" width="52" height="4" rx="2" :fill="NETRAL_GELAP" />
          <rect x="8" y="20" width="24" height="16" rx="3" :fill="gradient[0]" />
          <rect x="36" y="20" width="24" height="16" rx="3" :fill="gradient[1]" />
          <rect x="8" y="42" width="24" height="16" rx="3" :fill="NETRAL" />
          <rect x="36" y="42" width="24" height="16" rx="3" :fill="NETRAL_GELAP" />
          <rect x="8" y="68" width="52" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect x="8" y="78" width="34" height="5" rx="2.5" :fill="NETRAL" />
        </g>
      </g>

      <!-- ============ TUGAS KULIAH: lembar soal + checklist ============ -->
      <g v-else-if="bentukAktif === 'tugas_kuliah'" transform="translate(48 26)">
        <rect width="200" height="148" rx="6" :fill="PANEL" opacity="0.98" />
        <g :stroke="NETRAL_TERANG" stroke-width="1">
          <line x1="0" y1="34" x2="200" y2="34" />
          <line x1="0" y1="58" x2="200" y2="58" />
          <line x1="0" y1="82" x2="200" y2="82" />
          <line x1="0" y1="106" x2="200" y2="106" />
          <line x1="0" y1="130" x2="200" y2="130" />
        </g>
        <line x1="34" y1="0" x2="34" y2="148" stroke="#FCA5A5" stroke-width="1" />
        <rect x="14" y="14" width="80" height="7" rx="3.5" :fill="gradient[0]" opacity="0.9" />
        <rect x="102" y="14" width="34" height="7" rx="3.5" :fill="NETRAL" />
        <g transform="translate(12 44)">
          <rect width="9" height="9" rx="2" :fill="gradient[0]" opacity="0.85" />
          <path
            d="M2.2 4.6 L3.8 6.4 L6.9 2.6"
            fill="none"
            stroke="#ffffff"
            stroke-width="1.4"
            stroke-linecap="round"
          />
          <rect x="16" width="96" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect x="120" width="42" height="5" rx="2.5" :fill="NETRAL" />
        </g>
        <g transform="translate(12 68)">
          <rect width="9" height="9" rx="2" :fill="gradient[0]" opacity="0.85" />
          <path
            d="M2.2 4.6 L3.8 6.4 L6.9 2.6"
            fill="none"
            stroke="#ffffff"
            stroke-width="1.4"
            stroke-linecap="round"
          />
          <rect x="16" width="74" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect x="120" width="56" height="5" rx="2.5" :fill="NETRAL" />
        </g>
        <g transform="translate(12 92)">
          <rect width="9" height="9" rx="2" :fill="NETRAL" />
          <rect x="16" width="104" height="5" rx="2.5" :fill="NETRAL_GELAP" />
          <rect x="120" width="30" height="5" rx="2.5" :fill="NETRAL" />
        </g>
        <g transform="translate(12 116)">
          <rect width="9" height="9" rx="2" :fill="NETRAL" />
          <rect x="16" width="66" height="5" rx="2.5" :fill="NETRAL_GELAP" />
        </g>
        <g transform="translate(150 12)">
          <circle cx="18" cy="18" r="17" :fill="gradient[0]" opacity="0.14" />
          <circle
            cx="18"
            cy="18"
            r="17"
            fill="none"
            :stroke="gradient[0]"
            stroke-width="2"
            stroke-dasharray="70 40"
            opacity="0.8"
          />
          <rect x="11" y="15" width="14" height="5" rx="2.5" :fill="gradient[0]" />
        </g>
      </g>

      <!-- ============ FALLBACK: kartu generik ============ -->
      <g v-else transform="translate(52 48)">
        <rect width="216" height="104" rx="8" :fill="PANEL" opacity="0.97" />
        <rect x="16" y="16" width="48" height="48" rx="10" :fill="gradient[0]" opacity="0.75" />
        <rect x="76" y="20" width="86" height="7" rx="3.5" :fill="NETRAL_GELAP" />
        <rect x="76" y="34" width="110" height="5" rx="2.5" :fill="NETRAL" />
        <rect x="76" y="46" width="64" height="5" rx="2.5" :fill="NETRAL" />
        <rect x="16" y="78" width="60" height="12" rx="6" :fill="gradient[0]" opacity="0.85" />
        <rect x="84" y="78" width="48" height="12" rx="6" :fill="NETRAL_TERANG" />
      </g>
    </svg>

    <!-- ikon kategori -->
    <div
      class="absolute bottom-3 right-3 grid h-9 w-9 place-items-center rounded-lg border border-border-subtle bg-surface-container-lowest/95 shadow-sm backdrop-blur"
    >
      <span class="material-symbols-outlined text-lg text-on-surface-variant" aria-hidden="true">{{
        icon
      }}</span>
    </div>
  </div>
</template>
