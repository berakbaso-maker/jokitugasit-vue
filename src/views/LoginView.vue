<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
import { USE_DEMO_AUTH } from '../stores/auth'

const email = ref('')
const password = ref('')
const errorMsg = ref('')
const loading = ref(false)
const showPassword = ref(false)

onMounted(() => {
  if (auth.isEngineer) router.replace(route.query.redirect || '/dashboard')
})

async function handleLogin() {
  errorMsg.value = ''
  if (!email.value.trim() || !password.value) {
    errorMsg.value = 'Email dan password wajib diisi.'
    return
  }
  loading.value = true
  try {
    await auth.login(email.value.trim(), password.value)
    router.replace(route.query.redirect || '/dashboard')
  } catch (err) {
    errorMsg.value = err.message || 'Login gagal. Periksa email & password.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="bg-background text-on-background font-body-md antialiased min-h-screen flex flex-col items-center justify-center p-gutter">
    <div class="w-full max-w-md">
      <div class="text-center mb-8">
        <div class="inline-flex items-center justify-center w-16 h-16 bg-electric-blue rounded-2xl shadow-lg mb-4">
          <span class="material-symbols-outlined text-surface-white text-3xl" style="font-variation-settings: 'FILL' 1">terminal</span>
        </div>
        <h1 class="font-headline-lg text-headline-lg text-on-surface mb-1">Engineer Login</h1>
        <p class="font-body-md text-body-md text-secondary">Masuk untuk akses dashboard, request, dan earnings.</p>
        <p v-if="USE_DEMO_AUTH" class="text-xs text-secondary mt-2">Mode demo lokal: gunakan admin / admin</p>
      </div>

      <div class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-6 md:p-8">
        <form class="space-y-5" @submit.prevent="handleLogin">
          <div>
            <label class="block font-label-bold text-label-bold text-on-background mb-2" for="email">Username / Email</label>
            <input
              id="email"
              v-model="email"
              class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
              placeholder="admin"
              type="text"
              autocomplete="username"
            />
          </div>
          <div>
            <label class="block font-label-bold text-label-bold text-on-background mb-2" for="password">Password</label>
            <div class="relative">
              <input
                id="password"
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 pr-12 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
                placeholder="••••••••"
                autocomplete="current-password"
              />
              <button
                type="button"
                class="absolute inset-y-0 right-0 flex items-center px-4 text-secondary hover:text-electric-blue transition-colors"
                :aria-label="showPassword ? 'Sembunyikan password' : 'Tampilkan password'"
                :title="showPassword ? 'Sembunyikan password' : 'Tampilkan password'"
                @click="showPassword = !showPassword"
              >
                <span class="material-symbols-outlined text-[20px]">{{ showPassword ? 'visibility_off' : 'visibility' }}</span>
              </button>
            </div>
          </div>

          <div v-if="errorMsg" class="bg-error-container text-on-error-container rounded-lg px-4 py-3 font-body-md text-body-md">
            {{ errorMsg }}
          </div>

          <button
            class="w-full bg-electric-blue text-surface-white font-label-bold text-label-bold py-4 rounded-xl flex items-center justify-center gap-2 hover:opacity-90 active:scale-95 transition-all shadow-md min-h-[44px] disabled:opacity-60"
            type="submit"
            :disabled="loading"
          >
            <span v-if="loading" class="material-symbols-outlined animate-spin">progress_activity</span>
            <span v-else class="material-symbols-outlined">login</span>
            {{ loading ? 'Masuk...' : 'Masuk' }}
          </button>
        </form>
      </div>

      <p class="text-center mt-6">
        <a class="inline-flex items-center gap-2 text-electric-blue font-label-bold text-label-bold hover:underline cursor-pointer" @click="router.push('/')">
          <span class="material-symbols-outlined text-[18px]">arrow_back</span>
          Kembali ke Beranda
        </a>
      </p>
    </div>
  </div>
</template>