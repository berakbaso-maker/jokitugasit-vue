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
})

export default router
