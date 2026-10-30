import { createApp } from 'vue'
import { createPinia } from 'pinia'

import './assets/main.css'
import App from './App.vue'
import router from './router'
import { inisialisasiTema } from './lib/tema'

const app = createApp(App)

app.use(createPinia())
app.use(router)

// Aktifkan tema tersimpan / preferensi sistem sebelum render pertama.
inisialisasiTema()

app.mount('#app')