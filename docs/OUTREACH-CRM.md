# IG Outreach & Referral Manager

Modul internal untuk mendata akun angkatan, prospek, antrean DM, klien, proyek,
pembayaran, dan komisi referral 10%. Bagian dari aplikasi `jokitugasit-vue`.

Dokumen produk, alur kerja, model omzet, dan compliance matrix ada di
[`PRD-OUTREACH.md`](./PRD-OUTREACH.md). Panduan pemakaian dari nol sampai
produksi (HTML, bisa dibuka offline) ada di
[`panduan-lengkap.html`](./panduan-lengkap.html) — jalankan `make guide`.
Dokumen ini fokus pada teknis: schema, RLS, migration, dan aturan uang.

**Bukan bot.** Tidak ada kredensial Instagram, tidak ada pengiriman DM otomatis,
tidak ada scraping followers/following. Semua pesan dikirim manual oleh kamu dari
aplikasi Instagram setelah disalin dari sini.

---

## 1. Urutan migration (wajib, jangan diacak)

Jalankan di Supabase SQL Editor **berurutan**. Semua idempoten, tapi urutannya
penting karena saling bergantung.

| # | File | Isi |
|---|---|---|
| 1 | `schema.sql` | tabel dasar: `profiles`, `requests`, `transactions` |
| 2 | `migration-delivery-walkthrough.sql` | kolom walkthrough |
| 3 | `migration-referral-partner.sql` | tabel `partners`, kolom `referral_code` |
| 4 | `ig-schema.sql` | lead/konten Instagram (opsional, tidak dipakai modul ini) |
| 5 | `migration-security-hardening.sql` | **wajib** — menutup kebocoran RLS |
| 6 | `migration-outreach-schema.sql` | target accounts, prospek, template, log |
| 7 | `migration-money-schema.sql` | payments, commissions, analytics, portal partner |
| 8 | `migration-payment-flow.sql` | status proyek dari pembayaran, `void_payment` |
| 9 | `migration-analytics-source.sql` | window analytics, kolom `requests.source` |
| 10 | `migration-import-batches.sql` | audit import, statistik, konversi prospek |
| 11 | `migration-referral-integrity.sql` | guard self-referral (nomor WhatsApp) |
| 12 | `migration-data-rights.sql` | hapus prospek + suppression list |
| 13 | `migration-project-details.sql` | kolom campus/stack proyek, analytics per kampus |
| 14 | `migration-hardening.sql` | kode referral acak, bucket privat, chunk import |

> Jika `ig-schema.sql` sudah pernah dijalankan, tetap jalankan nomor 5 karena
> file itu juga mendefinisikan ulang `is_engineer()`.

## 2. Kenapa nomor 5 tidak boleh dilewat

| Masalah lama | Akibat | Perbaikan |
|---|---|---|
| `requests_anon_select_status using (true)` | siapa pun dengan anon key bisa membaca nama, WhatsApp, deskripsi, `internal_notes`, `quote_amount` semua order | policy dihapus, diganti RPC `track_request(order_no)` |
| `requests_anon_insert with check (true)` | anon bisa menulis `quote_amount` / `internal_notes` / `status` palsu | policy dihapus, diganti RPC `create_public_request(...)` |
| `partners_anon_validate_code using (status='active')` | anon bisa membaca `full_name`, `whatsapp`, `ewallet_info` semua partner | policy dihapus, diganti RPC `validate_referral_code(code)` |
| `transactions_engineer_select using (true)` | semua akun login bisa membaca seluruh transaksi | diganti `using (public.is_engineer())` |

**Setelah migration 5 dijalankan, deploy frontend versi baru.** Frontend lama
memanggil `select * from requests` dan akan menampilkan halaman kosong.

## 3. Setelan Supabase yang harus dicek manual

- **Authentication → Providers → Email → "Allow new users to sign up"** → matikan.
  Tidak ada alur signup customer di aplikasi ini; membiarkannya aktif hanya
  menambah permukaan serangan.
- Pastikan akun engineer punya `profiles.role = 'engineer'`.
- Backup harian aktif (Database → Backups).
- Bucket `attachments` sekarang **privat** dengan batas 10 MB (PDF/ZIP/gambar/TXT).
  Migration mencoba mengubah bucket + policy otomatis. Kalau project Anda belum
  punya schema `storage` saat migration dijalankan, set manual di Dashboard:
  bucket private, lalu policy select untuk `authenticated` dengan
  `public.is_engineer()` dan insert untuk `anon`.
- Lampiran baru disimpan sebagai **path** dan dibuka lewat signed URL (1 jam).
  Data lama yang menyimpan URL publik tetap bisa dibuka, tetapi URL publik lama
  akan berhenti bekerja setelah bucket dijadikan privat.

## 4. Menjalankan test

```bash
# test logika frontend (parser CSV, normalisasi username, render template)
npm run test

# test migration + aturan database terhadap PostgreSQL lokal
npm run test:db

# keduanya
npm run test:all
```

`npm run test:db` membuat ulang database `jokitugasit_test`, menjalankan semua
migration di atas, lalu menjalankan test di `supabase/tests/`. Butuh `psql` dan
server PostgreSQL lokal. Tidak menyentuh Supabase production.

Yang diuji antara lain: anon tidak bisa membaca tabel sensitif, DP tidak
menghasilkan komisi, dua pembayaran tidak menggandakan komisi, refund mengurangi
nilai eligible, void pembayaran mengembalikan status proyek, dan status
do-not-contact tidak bisa dilepas oleh import ulang.

## 5. Aturan uang (jangan diubah tanpa test)

- Semua nominal `bigint` rupiah. Tidak ada float di mana pun.
- `total = quote_amount − discount_amount`.
- Komisi baru `ELIGIBLE` setelah **pembayaran terkonfirmasi ≥ total**. DP tidak
  cukup.
- Refund mengurangi nilai eligible. Refund penuh → `VOID`.
- Refund setelah komisi `PAID` → status `ADJUSTMENT`, nominal **tidak** ditulis
  ulang. Selesaikan manual.
- `amount = eligible_amount × rate_bps / 10000` (integer division, truncate).
  10% dari Rp333.333 = Rp33.333.
- `record_payment` idempoten lewat `idempotency_key`. Kirim kunci sama saat retry.
- **Status `paid` diturunkan dari pembayaran**, bukan dari klik manual. Proyek
  menjadi `paid` saat nilai bersih (pembayaran − refund) ≥ total. Kalau nilai
  bersih turun di bawah total dan proyek punya jejak pembayaran, status kembali
  `working` — refund penuh perlu ditutup manual karena status `cancelled` belum
  ada di skema.
- Proyek lama berstatus `paid` **tanpa** baris `payments` tidak pernah diturunkan
  oleh sinkronisasi ini.
- Salah input nominal diperbaiki lewat `void_payment(id, alasan)`: baris tidak
  dihapus, status jadi `VOID`, alasan tersimpan, komisi dihitung ulang.
- Payout komisi dicatat lewat `mark_commission_paid(id, bukti_url, catatan)`.
  Bukti dan catatan tersimpan di `commissions.payment_proof` / `note` dan bisa
  dibuka dari halaman partner. Rekap bisa difilter periode (semua/30 hari/bulan
  ini) dan diekspor CSV.
- Data partner (nama, WhatsApp, kampus, e-wallet, catatan) bisa diedit, tetapi
  **kode referral tidak berubah** supaya atribusi proyek lama tetap sah.
- **Self-referral ditolak.** Nomor WhatsApp klien dan partner dinormalisasi
  (`0831...` = `62831...`). Kalau sama, kode referral tidak disimpan saat
  request masuk, dan `recompute_commission` tidak akan pernah mencocokkan
  partner tersebut.

## 6. Aturan prospek

- `permission_basis` wajib: `MANUAL_ENTRY`, `ADMIN_SHARED_LIST`, `INBOUND_OPT_IN`.
- Username dinormalisasi di database: trim, buang `@`, lowercase.
- `do_not_contact` lengket. Import ulang tidak menghapusnya; trigger database
  menolak update yang mencoba melepasnya. Satu-satunya jalan adalah RPC
  `clear_do_not_contact(id, alasan)` yang menulis audit log.
- Antrean DM tidak pernah memuat prospek `DO_NOT_CONTACT` atau `NOT_INTERESTED`.
- `log_outreach` menolak mencatat pesan ke prospek yang sudah minta jangan
  dihubungi.

## 6b. Import, pagination, dan konversi

- Setiap import lewat `import_prospects_batch(...)` menulis satu baris
  `import_batches` (nama file, basis izin, jumlah baris, hasil validasi).
  File mentah tidak disimpan.
- File besar dikirim per 200 baris dengan `batch_id` yang sama; fungsi
  mengakumulasi hitungan ke satu baris batch, bukan membuat batch baru.
- Tabel prospek dipaginasi di server (25/halaman, filter status/kampus/cari
  ikut di query). Ekspor mengambil semua halaman secara bertahap.
- Prospek yang sudah sepakat bisa diubah jadi proyek lewat
  `create_request_from_prospect(...)`: membuat `requests` dengan `source =
  DIRECT_DM`, menautkan `prospect_id`, dan menandai prospek `CONVERTED`.
  Prospek DNC ditolak, dan satu prospek hanya bisa dikonversi sekali
  (unique index pada `requests.prospect_id`).
- Statistik antrean (`prospect_stats()`) dihitung di database, bukan dari
  daftar yang sudah diunduh browser.
- **Hapus prospek** memakai `delete_prospect(id, alasan, suppress)`. Baris
  prospek + log outreach dihapus, `requests.prospect_id` menjadi null. Kalau
  `suppress = true`, username masuk `prospect_suppressions` (hanya username +
  alasan, tanpa nama/kampus/nomor) sehingga import berikutnya melewatinya.
  Untuk koreksi salah input, pilih `suppress = false`.
- Akun target bisa diedit dan dihapus dari `/ops/targets`. Menghapus akun tidak
  menghapus prospek; hanya `source_account_id` yang dikosongkan (FK set null).
- Proyek punya kolom `campus` dan `stack` yang bisa diisi dari detail request.
  Konversi prospek mengisi `campus` otomatis dari data prospek.

## 7. Yang sengaja tidak dibangun

- Pengambilan daftar followers/following akun pihak ketiga. Business Discovery API
  hanya mengembalikan *jumlah* follower, bukan daftarnya. Jalur lain = scraping,
  melanggar ketentuan Meta.
- DM massal / cold DM otomatis. Messaging API hanya untuk percakapan yang dimulai
  pengguna (window 24 jam, atau satu private reply ke komentar).
- Penyimpanan password/cookie Instagram.
- Payment gateway. Pembayaran dicatat manual.
- Multi-tenant / portal mahasiswa.

## 8. Titik integrasi ke website

- Form request: `/request`, memvalidasi `referral_code` lewat RPC.
- Tracking: `/track`, memakai RPC `track_request`.
- Portal partner: `/partner`, memakai RPC `partner_portal` yang hanya
  mengembalikan data partner itu sendiri (tanpa WhatsApp/e-wallet).
- Dashboard engineer: `/dashboard`, memuat `analytics_overview` +
  `analytics_funnel` dengan filter periode (semua/30 hari/bulan ini), filter
  kampus, dan breakdown sumber klien (`DIRECT_DM`, `ADMIN_SHARE`, `REFERRAL`,
  `INBOUND`, `OTHER`).
- Pendapatan: `/earnings`, membaca `payments` + `commissions` (bukan tabel
  `transactions` lama). Detail proyek: `/requests/:id` punya panel pembayaran
  untuk mencatat DP/pelunasan/refund dan membatalkan salah input.

## 8b. Feature flag

Modul CRM bisa dimatikan tanpa deploy ulang kode atau menghapus data:

```bash
# Vercel > Project > Settings > Environment Variables
VITE_ENABLE_CRM=false
```

Efeknya: menu Antrean DM/Prospek/Akun Target/Template/Partner/Instagram hilang
dari sidebar, dan route `/ops/*`, `/engineer/partners`, `/ig-leads` dialihkan ke
`/dashboard`. Website publik, form request, tracking, portal partner, dan
dashboard utama tetap berjalan. Default (variabel tidak diisi) adalah aktif.

## 9. Retensi data (kebijakan, bukan otomatis)

Username + kampus + nomor WhatsApp termasuk data pribadi. Usulan kebijakan:

- Prospek tanpa interaksi 12 bulan → hapus (`delete from prospects where ...`).
- Prospek `DO_NOT_CONTACT` disimpan minimal 24 bulan agar suppression tetap
  berlaku, lalu dianonimkan.
- Data pembayaran/komisi disimpan sesuai kebutuhan pembukuan.
- Permintaan penghapusan dari individu: gunakan tombol **Hapus** dengan opsi
  suppression (atau RPC `delete_prospect(id, alasan, true)`), sehingga username
  tidak muncul lagi walau daftar diimpor ulang.

Ini masih perlu ditinjau terhadap UU PDP 27/2022 dan ketentuan pemasaran
elektronik yang berlaku. Bukan nasihat hukum.
