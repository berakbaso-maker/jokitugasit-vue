# Aturan Wajib Repo (tidak boleh dilewati)

Repo: `jokitugasit-vue` — Vue 3 + Supabase + Vercel.

1. **Muat skill `jokitugasit-production-gate` sebelum menyentuh kode.** Gate 0 (konteks) dan Gate 1 (rencana) wajib selesai sebelum edit file.
2. **`make gate` harus lulus sebelum commit dan sebelum deploy.** Kalau gagal, perbaiki — jangan lewati.
3. **Urutan deploy: SQL Supabase dulu, frontend kemudian.** Frontend baru memakai kolom/RPC yang belum tentu ada.
4. **Jangan pernah** menaruh service role key, password database, token Instagram, atau cookie di `VITE_*`, repo, atau commit.
5. **Migration harus additive.** Tidak ada `db reset`, `drop table`, atau hapus data produksi tanpa persetujuan eksplisit.
6. **Uang dihitung database**, bukan di browser. Komisi 10% tidak boleh dihitung ulang di Vue.
7. **Test yang tidak dijalankan tidak boleh diklaim lulus.** Sebutkan yang gagal/dilewati.
8. **Definition of Done** ada di akhir skill `jokitugasit-production-gate`; salin checklist-nya ke laporan akhir.

Perintah cepat:

```bash
make gate           # cek statis + unit + DB + build
make redeploy       # test → build → SQL → push → deploy → smoke
make guide          # panduan lengkap HTML
```

Dokumen acuan: `docs/OUTREACH-CRM.md`, `docs/PRD-OUTREACH.md`, `docs/DEPLOY.md`, `docs/panduan-lengkap.html`.
