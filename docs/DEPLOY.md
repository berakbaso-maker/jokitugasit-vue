# Deploy satu perintah — `make redeploy`

Satu perintah untuk seluruh siklus: **test → build → migration Supabase →
commit/push → deploy Vercel → smoke test**.

```bash
make redeploy
```

Dari root repo (`/Users/.../joki-tugas`) juga bisa, karena Makefile root
meneruskan ke `jokitugasit-vue`.

---

## Prasyarat (sekali saja)

```bash
npm install
npm i -g vercel
vercel login
vercel link          # project jokitugasit-vue
```

### Kredensial database (untuk migration otomatis)

Script membaca connection string dari **file terpisah**, bukan dari `~/.zshrc`,
supaya kredensial tidak tercampur dengan konfigurasi shell dan tidak ikut
ter-share/ter-commit.

**Cara paling mudah (otomatis):**
```bash
make db-setup
```
Perintah ini akan meminta URI connection string Postgres secara aman (input terselubung), menguji koneksi via `psql`, menyimpannya ke `~/.config/jokitugasit/db.env` (`chmod 600`), lalu langsung menjalankan migrasi `supabase/DEPLOY-ALL-IN-ONE.sql` + verifikasi.

Untuk menjalankan ulang migrasi database di lain waktu tanpa deploy frontend:
```bash
make db-push
```

Atau buat manual sekali:

```bash
mkdir -p ~/.config/jokitugasit
cat > ~/.config/jokitugasit/db.env <<'EOF'
SUPABASE_DB_URL="postgresql://postgres.<ref>:<PASSWORD>@<host>:5432/postgres?sslmode=require"
EOF
chmod 600 ~/.config/jokitugasit/db.env
```

Ambil nilainya dari **Supabase → Project Settings → Database → Connection
string (URI)**. Ganti `<PASSWORD>` dengan password database Anda.

`~/.zshrc` sudah memuat file ini otomatis (blok `jokitugasit deploy env`), dan
`scripts/redeploy.sh` juga memuatnya sendiri — karena `make` menjalankan
`/bin/bash` non-interaktif yang **tidak** membaca `~/.zshrc`. Jadi
`make redeploy` tetap menemukan kredensial walau dijalankan dari Makefile.

Lokasi file bisa diganti lewat `DEPLOY_ENV_FILE=/path/lain.env`.

Kalau ingin tanpa file: `make redeploy ARGS="--db-url postgresql://..."` atau
`SUPABASE_DB_URL="..." make redeploy`.

## Feature flag modul

| Variabel | Default | Efek |
|---|---|---|
| `VITE_ENABLE_CRM` | true | Master CRM; false = menu CRM hilang |
| `VITE_ENABLE_OUTREACH` | true | Target, prospek, DM, template |
| `VITE_ENABLE_CAMPAIGNS` | true | Halaman `/ops/campaigns` |
| `VITE_ENABLE_REFERRAL` | true | Partner & komisi |
| `VITE_ENABLE_INBOUND` | **false** | Inbound API (belum aktif) |

Set di Vercel → Environment Variables, lalu deploy ulang frontend.
Panduan kampanye/consent: `docs/GROWTH-PLAYBOOK.md`.

## Gate wajib sebelum commit/deploy

```bash
make gate              # statis + unit + DB + build
make gate ARGS="--static"   # cepat: secret scan, diff, bundle, docs
```

Gate menolak (exit non-zero) jika ada secret, `.env` ter-stage, migration
tidak tercakup bundle/test, fungsi kunci hilang, atau test/build gagal.
`make redeploy` otomatis menjalankan gate statis sebagai langkah 0b.

Aturan lengkapnya ada di `AGENTS.md` dan skill
`.opencode/skills/jokitugasit-production-gate/SKILL.md`.

Skill ini **khusus repo ini** (bukan global). Saat sesi dibuka dari folder induk
`/Users/rahoolll/joki-tugas`, sumbernya didaftarkan di
`/Users/rahoolll/joki-tugas/.opencode/opencode.jsonc`:

```jsonc
{ "skills": ["/Users/rahoolll/joki-tugas/jokitugasit-vue/.opencode/skills"] }
```

Isinya tetap satu salinan di repo. Path repo lain bisa diarahkan lewat
`JOKITUGASIT_REPO`.

## Yang dijalankan script

| # | Langkah | Gagal → |
|---|---|---|
| 0 | Preflight: branch `main`, Node, npm, git, Vercel, psql | berhenti |
| 1 | `npm test` (unit) | berhenti |
| 2 | `npm run test:db` kalau PostgreSQL lokal aktif | berhenti |
| 3 | `npm run build` | berhenti |
| 4 | Backup schema + `psql -f supabase/DEPLOY-ALL-IN-ONE.sql` + verifikasi 6 fungsi/4 kolom | berhenti |
| 5 | `git add -A` → commit → `git push origin main` | berhenti |
| 6 | `vercel --prod --yes --archive=tgz` (retry 3×) | berhenti |
| 7 | Smoke test 5 route publik (`/`, `/request`, `/track`, `/partner`, `/harga`) | berhenti |

Langkah 4 hanya berjalan kalau `SUPABASE_DB_URL` tersedia. Kalau tidak,
script memberi peringatan dan tetap deploy frontend — **fitur CRM baru akan
error sampai SQL dijalankan**.

Migration memakai `supabase/DEPLOY-ALL-IN-ONE.sql` yang idempoten, jadi aman
diulang. Backup default hanya schema (`pg_dump --schema-only`); pakai
`--backup` untuk dump penuh.

---

## Opsi

```bash
make redeploy ARGS="--help"

# Lewati migration (mis. SQL sudah dijalankan manual)
make redeploy ARGS="--skip-db"

# Hanya migration (tidak build/deploy)
make redeploy ARGS="--db-url postgresql://... --only-db"

# Hanya build + deploy (hotfix frontend)
make redeploy ARGS="--only-deploy"

# Backup penuh sebelum migration
SUPABASE_DB_URL="postgresql://..." make redeploy ARGS="--backup"

# Pesan commit kustom
make redeploy ARGS="--message 'feat: tambah filter kampus'"

# Cek prasyarat tanpa mengubah apa pun
make redeploy ARGS="--check"

# Deploy dari branch selain main (tidak disarankan)
make redeploy ARGS="--allow-branch"
```

| Flag | Efek |
|---|---|
| `--skip-tests` | lewati unit + DB test |
| `--skip-db` | lewati migration |
| `--skip-push` | lewati commit/push |
| `--skip-deploy` | lewati Vercel + smoke |
| `--only-db` | hanya migration |
| `--only-deploy` | build + deploy |
| `--db-url <url>` | connection string (atau env / `~/.config/jokitugasit/db.env`) |
| `--backup` | `pg_dump -Fc` penuh sebelum migration |
| `--message <text>` | pesan commit |
| `--allow-branch` | izinkan branch non-main |
| `--check` | preflight saja |
| `--yes` | diterima (no-op, untuk automation lain) |

---

## Rollback

```bash
vercel rollback                                  # kembali ke deployment sebelumnya
git revert <sha> --no-edit && git push origin main
```

Migration bersifat additive; tidak ada `db reset`. Kalau perlu mengembalikan
fungsi tertentu, jalankan ulang file migration sebelumnya (mis.
`migration-analytics-source.sql`).

Untuk mematikan modul CRM tanpa rollback kode:

```bash
vercel env add VITE_ENABLE_CRM production   # isi: false
make redeploy ARGS="--only-deploy"
```

Website publik, form request, tracking, dan portal partner tetap berjalan.

---

## Troubleshooting

| Gejala | Penyebab / solusi |
|---|---|
| `Branch saat ini 'x'` | checkout `main` atau `--allow-branch` |
| `psql tidak ditemukan` | `brew install postgresql` |
| `Deploy gagal ... fetch failed` | script retry 3×; kalau tetap gagal cek koneksi/Vercel status |
| Migration sukses tapi fitur error | pastikan frontend yang live adalah build terbaru; cek `vercel inspect` |
| `Password DB belum diisi` | edit `~/.config/jokitugasit/db.env`, ganti `<PASSWORD>` |
| `Tidak bisa terhubung ke database` | cek host/region & password; atau `chmod 600` file env |
| Setelah ganti `.zshrc` tetap tidak terbaca | jalankan `source ~/.zshrc` atau buka terminal baru (tidak berpengaruh ke `make`) |
| Ingin lihat perintah tanpa eksekusi | `--check` (preflight) atau `--skip-*` sesuai kebutuhan |
