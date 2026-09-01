# Setup Bot Sosmed JokiTugasIT

Integrasi ini memakai Telegram sebagai kontrol, Hermes + 9router sebagai agent, Vercel API sebagai boundary aman, Supabase untuk data, dan Instagram Graph API resmi.

## 1. Telegram

Bot Hermes saat ini adalah `@AssistantRahoolll_Bot`.

1. Buat grup Telegram bernama `JokiTugasIT Bot Control`.
2. Tambahkan `@AssistantRahoolll_Bot` dan promosikan menjadi admin.
3. Di BotFather, jalankan `/setprivacy`, pilih bot, lalu pilih `Disable` agar bot dapat membaca perintah non-command dalam grup. Alternatif lebih aman: biarkan privacy aktif dan selalu gunakan perintah yang diawali `/`.
4. Buat channel bernama `JokiTugasIT Bot Ops`.
5. Tambahkan bot sebagai admin channel dengan izin `Post Messages`.
6. Kirim satu pesan ke grup dan channel. Ambil ID dengan melihat update bot atau forward pesan ke bot ID helper. ID supergroup/channel biasanya dimulai `-100`.
7. Isi `TELEGRAM_NOTIFICATION_CHAT_ID` di Vercel dengan ID channel laporan.

Telegram Bot API tidak menyediakan endpoint untuk membuat grup/channel atau membuat bot menjadi admin. Langkah 1, 2, 4, dan 5 wajib dilakukan akun manusia di aplikasi Telegram.

## 2. Meta / Instagram

1. Ubah akun Instagram menjadi Professional (Business atau Creator).
2. Hubungkan akun ke Facebook Page.
3. Buat Meta Developer App dan tambahkan produk Instagram API.
4. Tambahkan callback `https://jokitugasit.my.id/api/ig-webhook`.
5. Gunakan nilai `IG_WEBHOOK_VERIFY_TOKEN` yang sama di Meta dan Vercel.
6. Subscribe minimal ke event comments dan mentions. Messaging membutuhkan review permission tambahan.
7. Buat long-lived access token dan dapatkan Instagram Professional Account ID.

Permission yang dibutuhkan bergantung fitur: `instagram_basic`, `instagram_content_publish`, `instagram_manage_comments`, dan `instagram_manage_insights`. DM membutuhkan `instagram_manage_messages` serta App Review.

## 3. Supabase

Jalankan `supabase/ig-schema.sql` setelah schema utama melalui Supabase SQL Editor.

## 4. Vercel environment

Tambahkan semua variabel server pada `.env.example` ke Vercel. Jangan memasukkan service-role key atau token Meta ke variabel berawalan `VITE_`.

Buat dua secret acak yang berbeda:

```bash
openssl rand -hex 32
```

Gunakan satu untuk `IG_WEBHOOK_VERIFY_TOKEN`, satu untuk `IG_AUTOMATION_SECRET`.

## 5. Hermes

Tambahkan ke `~/.hermes/.env`:

```dotenv
JOKITUGAS_API_URL=https://jokitugasit.my.id
IG_AUTOMATION_SECRET=nilai-yang-sama-dengan-vercel
```

Setelah deployment berhasil, buat cron hemat token tanpa agent:

```bash
hermes cron create "every 5m" --name jokitugas-instagram-scheduler --script jokitugas_ig_schedule.sh --no-agent --deliver telegram
hermes cron create "0 20 * * *" --name jokitugas-instagram-insights --script jokitugas_ig_insights.sh --no-agent --deliver telegram
```

Scheduler tidak memakai 9router. 9router hanya dipakai saat kamu meminta Hermes menyusun caption atau memahami perintah bebas.

## 6. Contoh perintah Telegram

- `Buat caption promosi jasa review dan debugging Laravel, target mahasiswa semester akhir.`
- `Post gambar ini ke Instagram dengan caption final tadi.`
- `Tampilkan insight Instagram hari ini.`
- `Balas komentar 123456 dengan ajakan konsultasi melalui halaman /request.`

Hermes harus meminta konfirmasi sebelum publish atau reply.
