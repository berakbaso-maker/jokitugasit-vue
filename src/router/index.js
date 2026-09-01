import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'landing',
      component: () => import('../views/LandingView.vue'),
    },
    {
      path: '/layanan',
      name: 'services',
      component: () => import('../views/ServicesView.vue'),
    },
    {
      path: '/cara-kerja',
      name: 'how-it-works',
      component: () => import('../views/HowItWorksView.vue'),
    },
    {
      path: '/tentang',
      name: 'about',
      component: () => import('../views/AboutView.vue'),
    },
    {
      path: '/tanya-jawab',
      name: 'faq',
      component: () => import('../views/FaqView.vue'),
    },
    {
      path: '/joki-tugas-kuliah-it',
      name: 'joki-tugas-kuliah',
      component: () => import('../views/JokiTugasKuliahView.vue'),
    },
    {
      path: '/joki-skripsi-it',
      name: 'joki-skripsi',
      component: () => import('../views/JokiSkripsiView.vue'),
    },
    {
      path: '/joki-tugas-mobile-app',
      name: 'joki-mobile',
      component: () => import('../views/JokiMobileView.vue'),
    },
    {
      path: '/joki-project-web',
      name: 'joki-web',
      component: () => import('../views/JokiWebView.vue'),
    },
    {
      path: '/solusi-tugas-it',
      name: 'solusi-tugas',
      component: () => import('../views/SolusiTugasView.vue'),
    },
    {
      path: '/joki-database-api',
      name: 'joki-database-api',
      component: () => import('../views/JokiDatabaseApiView.vue'),
    },
    {
      path: '/joki-aplikasi-desktop',
      name: 'joki-desktop',
      component: () => import('../views/JokiDesktopView.vue'),
    },
    {
      path: '/joki-data-science-ai',
      name: 'joki-data-science',
      component: () => import('../views/JokiDataScienceView.vue'),
    },
    {
      path: '/joki-desain-ui-ux',
      name: 'joki-design',
      component: () => import('../views/JokiDesignView.vue'),
    },
    {
      path: '/joki-debug-error',
      name: 'joki-debug',
      component: () => import('../views/JokiDebugView.vue'),
    },
    {
      path: '/request',
      name: 'request-submit',
      component: () => import('../views/RequestSubmitView.vue'),
    },
    {
      path: '/success/:orderNo',
      name: 'request-success',
      component: () => import('../views/RequestSuccessView.vue'),
    },
    {
      path: '/harga',
      name: 'pricing',
      component: () => import('../views/PricingView.vue'),
    },
    {
      path: '/testimoni',
      name: 'testimonials',
      component: () => import('../views/TestimonialsView.vue'),
    },
    {
      path: '/blog',
      name: 'blog',
      component: () => import('../views/BlogView.vue'),
    },
    {
      path: '/blog/:slug',
      name: 'blog-post',
      component: () => import('../views/BlogPostView.vue'),
    },
    {
      path: '/track',
      name: 'request-track',
      component: () => import('../views/TrackRequestView.vue'),
    },
    {
      path: '/track/:orderNo',
      name: 'request-track-order',
      component: () => import('../views/TrackRequestView.vue'),
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('../views/LoginView.vue'),
    },
    {
      path: '/requests', name: 'requests', component: () => import('../views/RequestsView.vue'), meta: { requiresEngineer: true },
    },
    {
      path: '/ig-leads', name: 'instagram', component: () => import('../views/InstagramView.vue'), meta: { requiresEngineer: true },
    },
    {
      path: '/settings', name: 'settings', component: () => import('../views/SettingsView.vue'), meta: { requiresEngineer: true },
    },
    {
      path: '/dashboard',
      name: 'dashboard',
      component: () => import('../views/DashboardView.vue'),
      meta: { requiresEngineer: true },
    },
    {
      path: '/requests/:id',
      name: 'request-detail',
      component: () => import('../views/RequestDetailView.vue'),
      meta: { requiresEngineer: true },
    },
    {
      path: '/earnings',
      name: 'earnings',
      component: () => import('../views/EarningsView.vue'),
      meta: { requiresEngineer: true },
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('../views/NotFoundView.vue'),
    },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (!auth.session && !auth.loading) {
    await auth.init()
  }
  if (to.meta.requiresEngineer && !auth.isEngineer) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

function setMetaTag(attr, key, content) {
  let el = document.head.querySelector(`meta[${attr}="${key}"]`)
  if (!el) {
    el = document.createElement('meta')
    el.setAttribute(attr, key)
    document.head.appendChild(el)
  }
  el.setAttribute('content', content)
}

router.afterEach((to) => {
  const titles = {
    landing: 'Jasa Bantu Tugas IT & Coding - JokiTugasIT.id',
    services: 'Layanan Jasa Bantu Tugas IT - JokiTugasIT.id',
    'how-it-works': 'Cara Kerja Jasa Bantu Tugas IT - JokiTugasIT.id',
    about: 'Tentang Kami - JokiTugasIT.id',
    faq: 'Tanya Jawab - JokiTugasIT.id',
    'joki-tugas-kuliah': 'Joki Tugas Kuliah IT Umum - JokiTugasIT.id',
    'joki-skripsi': 'Joki Skripsi IT & Final Project - JokiTugasIT.id',
    'joki-mobile': 'Joki Tugas Mobile App - Fix Bug UI & API Hari Ini - JokiTugasIT.id',
    'joki-web': 'Joki Project Web - Fix Error & CRUD - JokiTugasIT.id',
    'solusi-tugas': 'Direktori Solusi Tugas IT Mahasiswa - JokiTugasIT.id',
    'joki-database-api': 'Joki Database & API - Fix Query & Integrasi - JokiTugasIT.id',
    'joki-desktop': 'Joki Aplikasi Desktop - Java C++ Python - JokiTugasIT.id',
    'joki-data-science': 'Joki Data Science & AI - Analisis & ML - JokiTugasIT.id',
    'joki-design': 'Joki Desain UI/UX - Figma & Prototype - JokiTugasIT.id',
    'joki-debug': 'Jasa Debug & Benerin Error Kode - JokiTugasIT.id',
    'pricing': 'Harga Jasa Bantu Tugas IT - Mulai Rp20rb - JokiTugasIT.id',
    'testimonials': 'Testimoni Jasa Bantu Tugas IT - JokiTugasIT.id',
    'blog': 'Blog Tips Ngoding & Bantuan Tugas IT - JokiTugasIT.id',
    'blog-post': 'Artikel - JokiTugasIT.id',
    'request-submit': 'Kirim Project - JokiTugasIT.id',
    'request-success': 'Request Success - JokiTugasIT.id',
    login: 'Login Engineer - JokiTugasIT.id',
    dashboard: 'Engineer Dashboard - JokiTugasIT.id',
    requests: 'Requests - JokiTugasIT.id',
    instagram: 'Instagram Command Center - JokiTugasIT.id',
    settings: 'Settings - JokiTugasIT.id',
    'request-detail': 'Request Detail - JokiTugasIT.id',
    earnings: 'Earnings Dashboard - JokiTugasIT.id',
  }
  const title = titles[to.name] || 'JokiTugasIT.id - Jasa Bantu Tugas IT'
  document.title = title
  const url = 'https://jokitugasit.my.id' + to.path
  setMetaTag('property', 'og:title', title)
  setMetaTag('property', 'og:url', url)
  setMetaTag('name', 'twitter:title', title)

  // Per-page meta description
  const descriptions = {
    landing: 'Jasa bantu tugas IT dan coding untuk mahasiswa: web, aplikasi mobile, database, debug error, skripsi, dan tugas kuliah. Mulai Rp20rb, konsultasi gratis, tanpa daftar.',
    services: 'Layanan jasa bantu tugas IT lengkap: bikin website, aplikasi mobile & desktop, database & API, data science, debug error, skripsi, dan desain UI/UX.',
    'how-it-works': 'Cara kerja JokiTugasIT.id: kirim tugas, konsultasi gratis via WhatsApp, nego harga, deal, dan beres. Proses transparan dengan nomor tiket.',
    about: 'Kenalan dengan engineer JokiTugasIT.id: 5+ tahun pengalaman, alumni Ilmu Komputer, spesialisasi backend, frontend, mobile, dan DevOps.',
    faq: 'Pertanyaan umum tentang jasa bantu tugas IT: harga mulai Rp20rb, cara bayar DP, keamanan, revisi, deadline, dan cara cek status order.',
    'joki-tugas-kuliah': 'Joki tugas kuliah IT: pemrograman dasar, algoritma, struktur data, basis data. Bantu mahasiswa yang mentok ngoding. Konsultasi gratis.',
    'joki-skripsi': 'Joki skripsi IT dan final project: debug kode AI, integrasi API, fitur belum selesai, persiapan demo & deploy. Pendampingan sampai sidang.',
    'joki-mobile': 'Joki tugas mobile app: Flutter, React Native, Android, iOS. Fix build error, API tidak nyambung, UI berantakan. Deadline mepet? Bantu beres.',
    'joki-web': 'Joki project web: PHP, Laravel, React, Next.js. Fix error 404, auth & middleware, CRUD, sampai deploy. Landing page skripsi juga bisa.',
    'solusi-tugas': 'Direktori solusi tugas IT mahasiswa: web, mobile, database, data science, UI/UX, skripsi. Pilih kategori dan konsultasi gratis.',
    'joki-database-api': 'Joki database & API: desain skema, optimasi query, REST API / GraphQL. MySQL, PostgreSQL, Supabase. Project tidak berantakan.',
    'joki-desktop': 'Joki aplikasi desktop: Java, C++, Python, .NET. Fix error, GUI, dan logika program untuk tugas praktikum sampai skala lab.',
    'joki-data-science': 'Joki data science & AI: analisis data, machine learning, scraping. Python, Pandas, Scikit-learn, TensorFlow. Hasil rapi siap laporan.',
    'joki-design': 'Joki desain UI/UX: Figma, prototype, design system. Desain modern, responsive, dan siap slicing ke kode. Tampilan premium.',
    'joki-debug': 'Jasa debug & benerin error kode: kode ChatGPT error, runtime/build error, logic salah. Dicari akar masalahnya sampai benar-benar jalan.',
    pricing: 'Harga jasa bantu tugas IT transparan: Quick Fix mulai Rp20rb, Debugging mulai Rp30rb, AI Code Rescue mulai Rp50rb. Bisa ajukan budget sendiri.',
    testimonials: 'Testimoni mahasiswa yang dibantu JokiTugasIT.id: CRUD PHP, Flutter, skripsi, debug error, database. Cerita nyata, rating 4.9/5.',
    blog: 'Blog tips ngoding & bantuan tugas IT: cara debug error, tutorial CRUD PHP, contoh program Java, dan cara pilih jasa bantu tugas yang aman.',
    'blog-post': 'Artikel tips dan tutorial seputar tugas IT, debugging, dan pemrograman untuk mahasiswa Indonesia.',
    'request-submit': 'Kirim project atau tugas IT: isi form 30 detik, tanpa daftar, tanpa login. Dapat nomor tiket dan cek status kapan saja.',
    'request-track': 'Cek status order JokiTugasIT: masukkan nomor tiket untuk lihat progres pengerjaan tugas IT kamu.',
  }
  setMetaTag('name', 'description', descriptions[to.name] || descriptions.landing)
  setMetaTag('property', 'og:description', descriptions[to.name] || descriptions.landing)

  // BreadcrumbList JSON-LD
  const breadcrumbMap = {
    landing: [],
    services: [{ name: 'Layanan', path: '/layanan' }],
    'how-it-works': [{ name: 'Cara Kerja', path: '/cara-kerja' }],
    about: [{ name: 'Tentang', path: '/tentang' }],
    faq: [{ name: 'Tanya Jawab', path: '/tanya-jawab' }],
    pricing: [{ name: 'Harga', path: '/harga' }],
    testimonials: [{ name: 'Testimoni', path: '/testimoni' }],
    blog: [{ name: 'Blog', path: '/blog' }],
    'blog-post': [{ name: 'Blog', path: '/blog' }, { name: 'Artikel', path: to.path }],
    'joki-tugas-kuliah': [{ name: 'Layanan', path: '/layanan' }, { name: 'Joki Tugas Kuliah IT', path: '/joki-tugas-kuliah-it' }],
    'joki-skripsi': [{ name: 'Layanan', path: '/layanan' }, { name: 'Joki Skripsi IT', path: '/joki-skripsi-it' }],
    'joki-mobile': [{ name: 'Layanan', path: '/layanan' }, { name: 'Joki Mobile App', path: '/joki-tugas-mobile-app' }],
    'joki-web': [{ name: 'Layanan', path: '/layanan' }, { name: 'Joki Project Web', path: '/joki-project-web' }],
    'joki-database-api': [{ name: 'Layanan', path: '/layanan' }, { name: 'Joki Database & API', path: '/joki-database-api' }],
    'joki-desktop': [{ name: 'Layanan', path: '/layanan' }, { name: 'Joki Aplikasi Desktop', path: '/joki-aplikasi-desktop' }],
    'joki-data-science': [{ name: 'Layanan', path: '/layanan' }, { name: 'Joki Data Science', path: '/joki-data-science-ai' }],
    'joki-design': [{ name: 'Layanan', path: '/layanan' }, { name: 'Joki Desain UI/UX', path: '/joki-desain-ui-ux' }],
    'joki-debug': [{ name: 'Layanan', path: '/layanan' }, { name: 'Joki Debug Error', path: '/joki-debug-error' }],
    'request-submit': [{ name: 'Kirim Project', path: '/request' }],
    'request-track': [{ name: 'Cek Status', path: '/track' }],
  }
  const crumbs = breadcrumbMap[to.name] || []
  const breadcrumbItems = [
    { '@type': 'ListItem', position: 1, name: 'Beranda', item: 'https://jokitugasit.my.id/' },
    ...crumbs.map((c, i) => ({ '@type': 'ListItem', position: i + 2, name: c.name, item: 'https://jokitugasit.my.id' + c.path })),
  ]
  const bcJson = { '@context': 'https://schema.org', '@type': 'BreadcrumbList', itemListElement: breadcrumbItems }
  let bcScript = document.getElementById('breadcrumb-jsonld')
  if (!bcScript) {
    bcScript = document.createElement('script')
    bcScript.id = 'breadcrumb-jsonld'
    bcScript.type = 'application/ld+json'
    document.head.appendChild(bcScript)
  }
  bcScript.textContent = JSON.stringify(bcJson)
})

export default router
