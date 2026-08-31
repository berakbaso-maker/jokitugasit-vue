import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'

// DEMO LOCAL ONLY: set false when Supabase Auth is ready for real use.
export const USE_DEMO_AUTH = true
const DEMO_USERNAME = 'admin'
const DEMO_PASSWORD = 'admin'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    session: null,
    profile: null,
    loading: false,
  }),
  getters: {
    isAuthenticated: (state) => !!state.session,
    isEngineer: (state) => state.profile?.role === 'engineer',
  },
  actions: {
    async init() {
      this.loading = true
      const { data } = await supabase.auth.getSession()
      this.session = data.session
      if (this.session) await this.loadProfile()
      this.loading = false

      supabase.auth.onAuthStateChange(async (_event, session) => {
        this.session = session
        if (session) await this.loadProfile()
        else this.profile = null
      })
    },
    async loadProfile() {
      if (!this.session) return
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', this.session.user.id)
        .maybeSingle()
      this.profile = data
    },
    async login(email, password) {
      if (USE_DEMO_AUTH) {
        if (email.trim().toLowerCase() !== DEMO_USERNAME || password !== DEMO_PASSWORD) {
          throw new Error('Username atau password demo salah. Gunakan admin / admin.')
        }
        this.session = { user: { email: 'admin@jokitugasit.local' }, demo: true }
        this.profile = { full_name: 'Admin Demo', email: 'admin@jokitugasit.local', role: 'engineer', whatsapp: '81200000000' }
        return { session: this.session }
      }
      const { data, error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) throw error
      this.session = data.session
      await this.loadProfile()
      if (!this.isEngineer) {
        await supabase.auth.signOut()
        this.session = null
        this.profile = null
        throw new Error('Akun ini bukan akun engineer. Akses dashboard ditolak.')
      }
      return data
    },
    async logout() {
      await supabase.auth.signOut()
      this.session = null
      this.profile = null
    },
  },
})