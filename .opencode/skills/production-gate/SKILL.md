---
name: production-gate
description: WAJIB dipakai untuk setiap perubahan kode, migration, test, atau deploy di repo jokitugasit-vue (Vue 3 + Supabase + Vercel). Gunakan sebelum mengedit file, sebelum commit, dan sebelum push ke produksi. Mencakup gate development, testing, keamanan, migration Supabase, deploy Vercel, verifikasi, dan rollback. Jika tugas menyentuh kode, data, atau deploy di repo ini, skill ini tidak boleh dilewati.
---
# Production Gate

## Tujuan

Mencegah perubahan yang tampak benar di lokal tetapi merusak produksi: SQL belum jalan, RLS bocor, komisi salah, secret ikut ter-commit, atau frontend naik sebelum schema.

Skill ini adalah **prosedur**, bukan teori. Setiap gate punya syarat lulus dan kondisi berhenti.

## Mandatory trigger

Pakai skill ini jika salah satu benar:

- Mengubah/menambah file di `src/`, `api/`, `supabase/`, `scripts/`, `tests/`, atau `Makefile`.
- Menjalankan migration, deploy, rollback, atau mengubah data.
- Menyimpulkan "sudah selesai", "sudah dites", atau "sudah deploy".

Kalau hanya membaca/menjawab pertanyaan, skill ini tidak perlu.

**Larangan:** menulis kode sebelum Gate 0 dan Gate 1 selesai.

---

## Aturan non-negosiasi

1. **SQL dulu, frontend kemudian.** Migration additive dijalankan dan diverifikasi sebelum build frontend dinaikkan.
2. **Tidak ada secret di repo.** Service role, password DB, token IG, cookie tidak boleh ada di file yang di-commit atau di bundle browser.
3. **RLS adalah otorisasi.** Menyembunyikan menu/route bukan pengamanan.
4. **Uang dihitung database.** `bigint` rupiah, komisi 10% tidak dihitung di Vue.
5. **Test merah = berhenti.** Tidak ada commit/deploy saat test gagal.

---

## Gate 0 — Konteks (sebelum menyentuh file)

Baca yang relevan:

- `AGENTS.md`
- `docs/OUTREACH-CRM.md` (schema, RLS, aturan uang)
- `docs/PRD-OUTREACH.md` (alur, status, compliance)
- `docs/DEPLOY.md` (deploy & rollback)

Lalu periksa:

```bash
git status --short
git log --oneline -5
git branch --show-current
```

**Lulus jika:** paham perubahan yang diminta, area yang terdampak, dan tidak ada perubahan user yang belum di-commit yang akan tertimpa.
**Berhenti jika:** working tree berisi perubahan asing yang tidak dipahami, branch bukan `main` untuk pekerjaan deploy, atau repo berada di kondisi merge/rebase.

---

## Gate 1 — Rencana (wajib sebelum kode)

Tuliskan singkat:

| Item | Isi |
|---|---|
| Perubahan | apa yang berubah, untuk siapa |
| File | daftar file yang disentuh |
| Schema | tabel/kolom/RPC baru (kalau ada) |
| RLS | siapa boleh baca/tulis |
| Uang | apakah menyentuh pembayaran/komisi |
| Rollback | langkah kembali |
| Risiko | yang bisa rusak |

**Lulus jika:** rencana muat dalam beberapa baris dan rollback jelas.
**Berhenti jika:** butuh menghapus data, mengubah tipe kolom berisi data, atau mengganti signature RPC yang dipakai frontend lama tanpa rencana kompatibilitas.

---

## Gate 2 — Implementasi

- Ikuti konvensi repo: Vue `<script setup>`, JS (bukan TS), `src/lib/*` untuk service, `supabase/migration-*.sql` additive.
- SQL: `create table if not exists`, `add column if not exists`, `create or replace function`.
- Jangan menambah dependency tanpa alasan; cek yang sudah ada.
- Jangan mengubah perilaku publik (`/`, `/request`, `/track`, `/partner`) tanpa uji regresi.
- Jangan menaruh `service_role` di `src/` atau `VITE_*`.
- Update dokumentasi bila mengubah fitur/schema.

**Lulus jika:** perubahan kecil, konsisten, dan bisa dijelaskan per file.
**Berhenti jika:** muncul kebutuhan rewrite, backend baru, atau perubahan destruktif.

---

## Gate 3 — Testing

```bash
npm test            # 39 unit test
npm run test:db     # 11 suite (butuh PostgreSQL lokal)
npm run build
```

Aturan:

- Jangan mengklaim test lulus jika tidak dijalankan.
- Test DB membuat ulang `jokitugasit_test` — **jangan** arahkan ke produksi.
- Perubahan uang wajib punya test: DP, pelunasan, refund, void, idempotency, self-referral.
- Perubahan RLS wajib punya test anon + non-engineer + engineer.
- Perubahan UI tanpa test otomatis: uji manual dan catat langkahnya.

**Lulus jika:** semua hijau, atau kegagalan dijelaskan dan disetujui.
**Berhenti jika:** ada test merah, test dilewati tanpa alasan, atau hasil test tidak bisa direproduksi.

---

## Gate 4 — Review sebelum commit

```bash
make gate
git diff --stat
git diff
```

Periksa manual:

- [ ] Tidak ada `.env` / kredensial / JWT ikut ter-stage.
- [ ] Tidak ada `console.log` debug yang bocor data.
- [ ] Migration baru masuk `supabase/tests/run.sh` dan `DEPLOY-ALL-IN-ONE.sql`.
- [ ] Fungsi baru diberi `revoke`/`grant` yang benar.
- [ ] RLS aktif untuk tabel baru + policy engineer.
- [ ] Dokumentasi diperbarui.
- [ ] Rollback diketahui.

**Berhenti jika:** secret terdeteksi, RLS tidak jelas, atau migration tidak tercakup bundle.

---

## Gate 5 — Deploy

Urutan wajib:

1. Backup (otomatis via `make redeploy`, atau manual).
2. SQL Supabase.
3. Verifikasi 6 fungsi + 4 kolom.
4. Frontend.

```bash
make redeploy
# atau bertahap:
make redeploy ARGS="--only-db"
make redeploy ARGS="--only-deploy"
```

**Lulus jika:** deploy sukses, alias mengarah ke build baru, smoke test 5 route 200.
**Berhenti jika:** SQL gagal, verifikasi fungsi/kolom tidak lengkap, atau smoke test gagal. Jangan menaikkan frontend.

---

## Gate 6 — Verifikasi produksi

Uji minimal:

- [ ] `/` tampil normal.
- [ ] `/request` bisa kirim (dengan dan tanpa lampiran).
- [ ] `/track` menemukan order baru.
- [ ] `/partner` bisa daftar → dapat kode `REF-XXXXXXXX`.
- [ ] Login engineer → dashboard, filter periode & kampus.
- [ ] Satu siklus: prospek → klien → DP → pelunasan → komisi → tandai lunas.

Catat yang tidak bisa diuji (mis. butuh kredensial) secara eksplisit.

---

## Gate 7 — Catat

- Commit message menjelaskan **apa** dan **kenapa**.
- Sebutkan file migration yang harus dijalankan.
- Sebutkan SHA rollback (`git revert <sha>` / `vercel rollback`).
- Sebutkan follow-up yang belum selesai.

---

## Stop conditions (berhenti, jangan lanjut)

1. Test gagal.
2. Tidak ada akses database produksi tetapi diminta deploy frontend yang bergantung pada schema baru.
3. Secret terdeteksi di diff.
4. Migration destruktif tanpa persetujuan.
5. Perubahan menurunkan status data historis (mis. `paid` → `working` massal).
6. RLS baru membuka data ke anon/non-engineer.
7. Smoke test produksi gagal.
8. Permintaan mengklaim test/deploy yang tidak dijalankan.

---

## Anti-patterns

| Jangan | Lakukan |
|---|---|
| Deploy frontend sebelum SQL | `make redeploy ARGS="--only-db"` dulu |
| Hitung komisi di Vue | Baca `commissions.amount` dari database |
| `using (true)` untuk data prospek | `using (public.is_engineer())` |
| Hapus baris pembayaran | `void_payment(id, alasan)` |
| Simpan kode di client | RPC `generate_referral_code` |
| `db reset` ke produksi | Migration additive |
| Menyembunyikan menu sebagai pengamanan | RLS + RPC guard |
| "Sepertinya jalan" | Jalankan test + smoke test |

---

## Definition of Done

Salin ke laporan akhir:

```
[ ] Gate 0–1 selesai (konteks + rencana)
[ ] Perubahan sesuai konvensi repo
[ ] npm test lulus (jumlah disebut)
[ ] npm run test:db lulus (jumlah suite disebut)
[ ] npm run build lulus
[ ] make gate lulus
[ ] Tidak ada secret di diff
[ ] Migration additive + masuk bundle + run.sh
[ ] RLS diuji (anon / non-engineer / engineer)
[ ] Dokumentasi diperbarui
[ ] SQL produksi dijalankan & diverifikasi (6 fungsi, 4 kolom)
[ ] Deploy sukses + smoke test 5 route
[ ] 6 alur inti diuji atau disebut yang belum
[ ] Rollback SHA dicatat
```

## Referensi cepat

```bash
make gate
make redeploy
make redeploy ARGS="--check"
make redeploy ARGS="--only-db"
make redeploy ARGS="--only-deploy"
make guide
```

Urutan SQL: lihat `docs/OUTREACH-CRM.md` §1, atau gunakan `supabase/DEPLOY-ALL-IN-ONE.sql`.
