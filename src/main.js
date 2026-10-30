import { createApp } from 'vue'
import { createPinia } from 'pinia'

import './assets/main.css'
import App from './App.vue'
import router from './router'
import { inisialisasiTema } from './lib/tema'
import { pasangPrefetch } from './lib/prefetch'

const app = createApp(App)

app.use(createPinia())
app.use(router)

// Aktifkan tema tersimpan / preferensi sistem sebelum render pertama.
inisialisasiTema()

app.mount('#app')

// Setelah aplikasi hidup, baru pasang prefetch supaya tidak menunda render awal.
pasangPrefetch(router)