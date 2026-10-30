<script setup>
import { RouterView } from 'vue-router'
</script>

<template>
  <!-- Tautan lompat: elemen fokus pertama di halaman. Tersembunyi sampai
       menerima fokus keyboard, jadi pengguna Tab tidak perlu melewati
       seluruh menu navigasi di setiap halaman. -->
  <a href="#konten-utama" class="skip-link">Lewati ke konten utama</a>
  <RouterView />
</template>
