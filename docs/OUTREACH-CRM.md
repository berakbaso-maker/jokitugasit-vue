# IG Outreach & Referral Manager

Modul internal untuk mendata akun angkatan, prospek, antrean DM, klien, proyek,
pembayaran, dan komisi referral 10%. Bagian dari aplikasi `jokitugasit-vue`.

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
nilai eligible, dan status do-not-contact tidak bisa dilepas oleh import ulang.

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

## 6. Aturan prospek

- `permission_basis` wajib: `MANUAL_ENTRY`, `ADMIN_SHARED_LIST`, `INBOUND_OPT_IN`.
- Username dinormalisasi di database: trim, buang `@`, lowercase.
- `do_not_contact` lengket. Import ulang tidak menghapusnya; trigger database
  menolak update yang mencoba melepasnya. Satu-satunya jalan adalah RPC
  `clear_do_not_contact(id, alasan)` yang menulis audit log.
- Antrean DM tidak pernah memuat prospek `DO_NOT_CONTACT` atau `NOT_INTERESTED`.
- `log_outreach` menolak mencatat pesan ke prospek yang sudah minta jangan
  dihubungi.

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
- Dashboard engineer: `/dashboard`, memuat `analytics_overview` + `analytics_funnel`.

## 9. Retensi data (kebijakan, bukan otomatis)

Username + kampus + nomor WhatsApp termasuk data pribadi. Usulan kebijakan:

- Prospek tanpa interaksi 12 bulan → hapus (`delete from prospects where ...`).
- Prospek `DO_NOT_CONTACT` disimpan minimal 24 bulan agar suppression tetap
  berlaku, lalu dianonimkan.
- Data pembayaran/komisi disimpan sesuai kebutuhan pembukuan.
- Permintaan penghapusan dari individu: hapus baris `prospects` dan tambahkan
  username ke tabel suppression terpisah bila perlu.

Ini masih perlu ditinjau terhadap UU PDP 27/2022 dan ketentuan pemasaran
elektronik yang berlaku. Bukan nasihat hukum.
