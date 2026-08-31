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
      path: '/engineer-login',
      name: 'engineer-login',
      component: () => import('../views/LoginView.vue'),
    },
    {
      path: '/requests', name: 'requests', component: () => import('../views/RequestsView.vue'), meta: { requiresEngineer: true },
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

router.afterEach((to) => {
  const titles = {
    landing: 'Jasa Bantu Tugas IT & Coding - JokiTugasIT.id',
    services: 'Layanan Jasa Bantu Tugas IT - JokiTugasIT.id',
    'how-it-works': 'Cara Kerja Jasa Bantu Tugas IT - JokiTugasIT.id',
    about: 'Tentang Kami - JokiTugasIT.id',
    faq: 'Tanya Jawab - JokiTugasIT.id',
    'joki-tugas-kuliah': 'Joki Tugas Kuliah IT Umum - JokiTugasIT.id',
    'joki-skripsi': 'Joki Skripsi IT & Final Project - JokiTugasIT.id',
    'request-submit': 'Kirim Project - JokiTugasIT.id',
    'request-success': 'Request Success - JokiTugasIT.id',
    login: 'Engineer Login - JokiTugasIT.id',
    'engineer-login': 'Engineer Login - JokiTugasIT.id',
    dashboard: 'Engineer Dashboard - JokiTugasIT.id',
    requests: 'Requests - JokiTugasIT.id',
    settings: 'Settings - JokiTugasIT.id',
    'request-detail': 'Request Detail - JokiTugasIT.id',
    earnings: 'Earnings Dashboard - JokiTugasIT.id',
  }
  document.title = titles[to.name] || 'JokiTugasIT.id'
})

export default router