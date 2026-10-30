# Arsitektur Gratis Tanpa VPS

Dokumen ini menjelaskan cara repo ini berjalan **tanpa VPS dan tanpa biaya
infrastruktur**: frontend di Vercel, database/auth/storage di Supabase, scheduler
di Vercel Cron (cadangan: GitHub Actions).

Tujuannya bukan meniru VPS literal, tetapi memberi rasa "punya server sendiri":
satu domain, API server-side, secret terpusat, database terkelola, cron, webhook,
deploy otomatis, dan rollback.

---

## 1. Peta komponen

```text
User
 │
 ▼
jokitugasit.my.id
 │
 ├── Frontend Vue (static) ──► Vercel
 ├── API serverless        ──► Vercel Functions (api/)
 ├── Scheduler             ──► Vercel Cron / GitHub Actions
 ├── Webhook Instagram     ──► /api/ig-webhook
 └── DB + Auth + Storage   ──► Supabase
```

| Kebutuhan | Pengganti gratis |
|---|---|
| Serve frontend | Vercel Static |
| Backend API | Vercel Functions |
| Cron job | Vercel Cron (`vercel.json`) |
| Database | Supabase Postgres |
| Auth | Supabase Auth |
| File attachment | Supabase Storage (bucket privat) |
| HTTPS/DNS | Vercel (opsional Cloudflare) |
| Secrets | Vercel Environment Variables |

Aturan desain karena serverless (bukan VPS):

- **Stateless.** Tidak ada filesystem permanen, tidak ada proses hidup 24 jam.
- **Idempotent.** Semua job scheduler/webhook aman dijalankan dua kali.
- **State di database.** Progres pekerjaan disimpan di Supabase, bukan di memori.
- **Batch kecil.** Pekerjaan panjang dipecah (contoh: 5 post per run).

---

## 2. Pembagian environment variable

Public (dibundel ke browser — **jangan** taruh secret):

```env
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
VITE_ENABLE_CRM=
VITE_ENABLE_OUTREACH=
VITE_ENABLE_CAMPAIGNS=
VITE_ENABLE_REFERRAL=
VITE_ENABLE_INBOUND=
```

Server-only (hanya Vercel Functions):

```env
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
CRON_SECRET=
IG_GRAPH_VERSION=
IG_USER_ID=
IG_ACCESS_TOKEN=
IG_APP_SECRET=
IG_WEBHOOK_VERIFY_TOKEN=
IG_AUTOMATION_SECRET=
TELEGRAM_BOT_TOKEN=
TELEGRAM_NOTIFICATION_CHAT_ID=
APP_URL=
```

`SUPABASE_SERVICE_ROLE_KEY`, token Instagram/Telegram, dan secret webhook tidak
boleh diawali `VITE_`.

---

## 3. Scheduler tanpa VPS

`api/ig-run-schedule.js` mempublikasi konten Instagram yang sudah jatuh tempo.
Endpoint ini **tidak bisa dipanggil tanpa secret**.

### GitHub Actions (dipakai sekarang)

Akun Vercel Hobby hanya mengizinkan cron 1x per hari, sehingga `"crons"` di
`vercel.json` ditolak saat deploy (`Hobby accounts are limited to daily cron
jobs`). Karena itu cron Vercel tidak dipakai dan scheduler dijalankan lewat
GitHub Actions: `.github/workflows/ig-scheduler.yml` (tiap 15 menit).

Set sekali di repo GitHub -> Settings -> Secrets and variables -> Actions:

| Tipe | Nama | Isi |
|---|---|---|
| Secret | `CRON_SECRET` | sama dengan env `CRON_SECRET` di Vercel |
| Variable | `APP_URL` | `https://jokitugasit.my.id` |

### Vercel Cron (kalau nanti upgrade ke Pro)

Kalau akun sudah Pro, boleh kembali memakai cron Vercel. Tambahkan ke
`vercel.json`:

```json
"crons": [{ "path": "/api/ig-run-schedule", "schedule": "*/15 * * * *" }]
```

Aktivasi:

1. Vercel → Project → Settings → Environment Variables.
2. Tambah `CRON_SECRET` (Production), isi string acak panjang:
   ```bash
   openssl rand -hex 32
   ```
3. Redeploy frontend/API.
4. Vercel Cron otomatis mengirim `Authorization: Bearer $CRON_SECRET`.

### Referensi workflow GitHub Actions

Isi workflow yang dipakai (`.github/workflows/ig-scheduler.yml`):

```yaml
name: ig-scheduler
on:
  schedule:
    - cron: "*/5 * * * *"
  workflow_dispatch:
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger scheduler
        run: |
          curl -fsS -X POST "${{ vars.APP_URL }}/api/ig-run-schedule" \
            -H "Authorization: Bearer ${{ secrets.CRON_SECRET }}" \
            -H "Content-Type: application/json" \
            --max-time 60 --retry 2
```

Catatan: jadwal GitHub Actions **tidak presisi** (bisa telat beberapa menit).
Cocok untuk publish terjadwal, tidak untuk pembayaran real-time.

### Uji manual

```bash
curl -X POST https://jokitugasit.my.id/api/ig-run-schedule \
  -H "Authorization: Bearer $CRON_SECRET"
```

### Perilaku scheduler

- Klaim atomik: `status = 'scheduled'` → `'publishing'` lewat update bersyarat.
  Dua invokasi paralel tidak akan mempublikasi konten yang sama.
- Pemulihan: post yang macet di `publishing` lebih dari 15 menit dikembalikan
  ke `scheduled` (function timeout / crash tidak mematikan job permanen).
- Batas 5 post per run agar aman terhadap batas durasi function.

---

## 4. Webhook Instagram

Alur:

```text
Meta ──► /api/ig-webhook ──► verifikasi signature ──► dedupe ──► Supabase
```

- `GET` dipakai verifikasi `hub.challenge` dengan `IG_WEBHOOK_VERIFY_TOKEN`.
- `POST` wajib lolos `x-hub-signature-256` (HMAC `IG_APP_SECRET`).
- Dedupe memakai `event_type + external_id`. Bila Meta tidak mengirim id, kunci
  fallback = hash isi event (`fallback:<type>:<sha256>`), sehingga retry webhook
  tidak menggandakan baris.

---

## 5. Deploy (tetap SQL dulu, frontend kemudian)

```bash
make gate            # statis + unit + DB + build
make redeploy        # test → build → SQL → push → deploy → smoke
```

Bila hanya mengubah API/cron (tanpa migration):

```bash
make redeploy
```

Rollback:

```bash
vercel rollback
git revert <sha> --no-edit && git push origin main
```

Mematikan modul tanpa rollback kode:

```bash
vercel env add VITE_ENABLE_CRM production   # isi: false
make redeploy ARGS="--only-deploy"
```

---

## 6. Backup gratis

| Data | Frekuensi | Lokasi |
|---|---|---|
| Schema | setiap perubahan migration | `pg_dump --schema-only` |
| Data transaksi | mingguan | dump terenkripsi, simpan lokal/Drive pribadi |
| Sebelum migration besar | wajib | `make redeploy ARGS="--backup"` |

Tabel prioritas backup: `requests`, `payments`, `commissions`, `partners`,
`profiles`, `prospects`, `campaigns`, `outreach_logs`.

Jangan simpan dump berisi data pribadi di repo publik.

---

## 7. Batasan model gratis (yang harus diterima)

| Layanan | Batasan | Mitigasi |
|---|---|---|
| Vercel Functions | durasi, invocation, cold start | batch kecil, job idempotent |
| Vercel Cron | jadwal minimum & kuota | fallback GitHub Actions |
| Supabase | kuota DB/storage, project bisa pause | pagination, retensi, bersihkan file |
| GitHub Actions | jadwal tidak presisi, kuota menit | hanya job ringan |

Konsekuensi: aplikasi **wajib** serverless-friendly. Jangan menambah proses
yang butuh koneksi panjang, worker permanen, atau state di filesystem.

---

## 8. Kapan sebenarnya perlu VPS

Hanya jika muncul kebutuhan yang tidak bisa dipenuhi model ini:

- Worker permanen / queue dengan latensi sangat rendah.
- Proses CPU/memori berat (> durasi function).
- Penyimpanan file lokal persisten.
- Koneksi database berumur panjang (mis. pooling agresif).

Selama belum ada kebutuhan itu, VPS hanya menambah biaya dan beban maintenance
(patch OS, TLS, monitoring, backup) tanpa manfaat nyata untuk situs sekala ini.
