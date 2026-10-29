#!/usr/bin/env bash
# ==============================================================================
# redeploy.sh — satu perintah untuk: test → build → migration → commit/push →
# deploy Vercel → smoke test.
#
# Contoh:
#   make redeploy
#   make redeploy ARGS="--skip-db"
#   make redeploy ARGS="--db-url postgresql://... --backup"
#   SUPABASE_DB_URL="postgresql://..." make redeploy
#
# Tanpa SUPABASE_DB_URL, migration dilewati dan script memberi peringatan
# (frontend tetap dideploy, tetapi fitur CRM baru akan error sampai SQL jalan).
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_BLUE=$'\033[38;5;39m'
C_GREEN=$'\033[38;5;82m'
C_YELLOW=$'\033[38;5;220m'
C_RED=$'\033[38;5;196m'
C_GRAY=$'\033[38;5;244m'

step()  { printf '\n%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
ok()    { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
fail()  { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
info()  { printf '%s·%s %s\n' "$C_GRAY" "$C_RESET" "$*"; }

usage() {
  cat <<'EOF'
Penggunaan: make redeploy [ARGS="..."]

Opsi:
  --skip-tests        Lewati unit test + test DB
  --skip-db           Jangan jalankan migration SQL
  --skip-push         Jangan commit/push ke Git
  --skip-deploy       Jangan deploy ke Vercel
  --only-db           Hanya jalankan migration SQL
  --only-deploy       Hanya build + deploy (tanpa test/migration/push)
  --db-url <url>      Connection string Postgres (atau env SUPABASE_DB_URL)
                      Default dibaca dari ~/.config/jokitugasit/db.env
  --backup            pg_dump penuh (-Fc) sebelum migration (default: schema-only)
  --message <text>    Pesan commit (default: chore(deploy): <timestamp>)
  --allow-branch      Izinkan deploy dari branch selain main
  --check             Preflight saja, tidak mengubah apa pun
  --self-test         Uji skrip + bundle SQL (tanpa deploy)
  -h, --help          Bantuan ini

Contoh:
  make redeploy
  make redeploy ARGS="--skip-db"
  SUPABASE_DB_URL="postgresql://postgres:...@db.xxx.supabase.co:5432/postgres" make redeploy
EOF
}

# ---------- defaults ----------
SKIP_TESTS=false
SKIP_DB=false
SKIP_PUSH=false
SKIP_DEPLOY=false
ONLY_DB=false
ONLY_DEPLOY=false
BACKUP=false
ALLOW_BRANCH=false
CHECK_ONLY=false
SELF_TEST=false
COMMIT_MSG="chore(deploy): $(date '+%Y-%m-%d %H:%M')"
# Make menjalankan /bin/bash (non-interaktif), jadi ~/.zshrc tidak dibaca.
# Muat file kredensial sendiri supaya `make redeploy` selalu menemukannya.
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-$HOME/.config/jokitugasit/db.env}"
if [ -z "${SUPABASE_DB_URL:-}" ] && [ -f "$DEPLOY_ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$DEPLOY_ENV_FILE" 2>/dev/null || true
  set +a
fi

DB_URL="${SUPABASE_DB_URL:-${DATABASE_URL:-}}"
if printf '%s' "$DB_URL" | grep -q '<PASSWORD>'; then
  DB_URL=""
  DB_PLACEHOLDER=true
else
  DB_PLACEHOLDER=false
fi
PROD_BASE="${PROD_URL:-https://jokitugasit.my.id}"
SMOKE_PATHS="/ /request /track /partner /harga"

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-tests)  SKIP_TESTS=true ;;
    --skip-db)     SKIP_DB=true ;;
    --skip-push)   SKIP_PUSH=true ;;
    --skip-deploy) SKIP_DEPLOY=true ;;
    --only-db)     ONLY_DB=true ;;
    --only-deploy) ONLY_DEPLOY=true ;;
    --backup)      BACKUP=true ;;
    --allow-branch) ALLOW_BRANCH=true ;;
    --check)       CHECK_ONLY=true ;;
    --self-test)   SELF_TEST=true ;;
    --db-url)      DB_URL="${2:-}"; shift ;;
    --message)     COMMIT_MSG="${2:-}"; shift ;;
    -h|--help)     usage; exit 0 ;;
    --yes)         ;; # diterima supaya kompatibel dengan automation lain
    *)             fail "Opsi tidak dikenal: $1 (pakai --help)" ;;
  esac
  shift
done

[ -n "$COMMIT_MSG" ] || fail "Pesan commit kosong (--message)."

if $ONLY_DB; then SKIP_DEPLOY=true; SKIP_PUSH=true; SKIP_TESTS=true; fi
if $ONLY_DEPLOY; then SKIP_DB=true; SKIP_PUSH=true; SKIP_TESTS=true; fi

mask_url() {
  # Jangan pernah mencetak password/host penuh.
  printf '%s' "$1" | sed -E 's#(postgres(ql)?://)[^@]*@#\1***@#'
}

# ---------- self test (tanpa menyentuh repo/deploy) ----------
if $SELF_TEST; then
  step "Self test"
  command -v bash >/dev/null || fail "bash tidak ada"
  # Pastikan tidak ada ekspansi variabel yang tidak sengaja (mis. variabel diikuti elipsis).
  RISKY="$(grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^A-Za-z0-9_ "/:.$)}]' "$0" \
    | grep -vE '\$ALLOW_BRANCH|\$SMOKE_PATHS|if ! \$|if \$' || true)"
  if [ -n "$RISKY" ]; then
    printf '%s\n' "$RISKY"
    fail "Ada ekspansi variabel berisiko (lihat baris di atas)."
  fi
  # Fungsi wajib ada di bundle SQL.
  for fn in void_payment import_prospects_batch analytics_campuses register_partner rotate_partner_code delete_prospect set_prospect_consent outreach_eligibility analytics_campaigns resolve_campaign; do
    grep -q "function public.${fn}" supabase/DEPLOY-ALL-IN-ONE.sql || fail "Bundle SQL tidak memuat ${fn}"
  done
  grep -q "make redeploy" docs/DEPLOY.md || fail "docs/DEPLOY.md belum menyebut make redeploy"
  ok "Tidak ada ekspansi variabel berisiko"
  ok "Bundle SQL memuat 10 fungsi kunci"
  ok "Dokumentasi deploy tersedia"
  exit 0
fi

# ---------- 0. preflight ----------
step "0/7 Preflight"
command -v node >/dev/null 2>&1 || fail "node tidak ditemukan."
command -v npm  >/dev/null 2>&1 || fail "npm tidak ditemukan."
command -v git  >/dev/null 2>&1 || fail "git tidak ditemukan."
[ -f package.json ] || fail "Jalankan dari root repo (package.json tidak ada)."

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] || $ALLOW_BRANCH || fail "Branch saat ini '$BRANCH'. Deploy hanya dari main (atau pakai --allow-branch)."

if ! $SKIP_DEPLOY; then
  command -v vercel >/dev/null 2>&1 || fail "Vercel CLI tidak ditemukan (npm i -g vercel)."
fi
if [ -n "$DB_URL" ]; then
  command -v psql >/dev/null 2>&1 || fail "psql tidak ditemukan, padahal --db-url/SUPABASE_DB_URL di-set."
  command -v pg_dump >/dev/null 2>&1 || fail "pg_dump tidak ditemukan."
fi

ok "Repo: $ROOT"
ok "Branch: $BRANCH"
ok "Node: $(node -v) · npm: $(npm -v)"
if [ -n "$DB_URL" ]; then
  ok "Database: $(mask_url "$DB_URL")  (dari ${DEPLOY_ENV_FILE/#$HOME/~})"
  if ! psql "$DB_URL" -tAc 'select 1' >/dev/null 2>&1; then
    fail "Tidak bisa terhubung ke database. Cek password/host di ${DEPLOY_ENV_FILE/#$HOME/~} (atau --db-url)."
  fi
  ok "Koneksi database: OK"
elif $DB_PLACEHOLDER; then
  $ONLY_DB && fail "Password belum diisi di ${DEPLOY_ENV_FILE/#$HOME/~} (masih <PASSWORD>)."
  warn "Password DB belum diisi di ${DEPLOY_ENV_FILE/#$HOME/~} → migration dilewati."
  warn "Edit file itu, ganti <PASSWORD>, lalu jalankan lagi."
else
  $ONLY_DB && fail "--only-db butuh --db-url atau SUPABASE_DB_URL."
  warn "SUPABASE_DB_URL tidak di-set → migration akan dilewati."
  warn "Buat ${DEPLOY_ENV_FILE/#$HOME/~} berisi SUPABASE_DB_URL=... (lihat docs/DEPLOY.md)."
fi

if $CHECK_ONLY; then
  ok "Preflight selesai (--check). Tidak ada perubahan."
  exit 0
fi

# ---------- 0b. gate statis ----------
step "0b/7 Gate statis (wajib)"
bash ./scripts/gate.sh --static
ok "Gate statis lulus"

# ---------- 1. tests ----------
if ! $SKIP_TESTS; then
  step "1/7 Unit test"
  npm test
  ok "Unit test lulus"

  step "2/7 Database test (lokal)"
  if command -v pg_isready >/dev/null 2>&1 && pg_isready -q 2>/dev/null; then
    npm run test:db
    ok "Migration + RLS test lulus"
  else
    warn "PostgreSQL lokal tidak aktif — test DB dilewati (production tidak disentuh)."
  fi
else
  step "1-2/7 Test dilewati (--skip-tests)"
fi

# ---------- 3. build ----------
if ! $ONLY_DB; then
  step "3/7 Build produksi"
  npm run build
  ok "Build selesai"
else
  step "3/7 Build dilewati (--only-db)"
fi

# ---------- 4. migration ----------
DB_STATUS="dilewati"
if ! $SKIP_DB; then
  step "4/7 Migration Supabase"
  if [ -z "$DB_URL" ]; then
    warn "Tidak ada SUPABASE_DB_URL / --db-url. SQL TIDAK dijalankan."
    warn "Jalankan manual: Supabase Dashboard → SQL Editor → supabase/DEPLOY-ALL-IN-ONE.sql"
    DB_STATUS="TIDAK dijalankan (butuh DB URL)"
  else
    mkdir -p backups
    STAMP="$(date '+%Y%m%d-%H%M%S')"

    if $BACKUP; then
      info "Backup penuh → backups/full-$STAMP.dump"
      pg_dump "$DB_URL" -Fc -f "backups/full-$STAMP.dump"
    else
      info "Backup schema → backups/schema-$STAMP.sql"
      pg_dump "$DB_URL" --schema-only --no-owner --no-privileges -f "backups/schema-$STAMP.sql"
    fi
    ok "Backup selesai"

    info "Menerapkan supabase/DEPLOY-ALL-IN-ONE.sql (idempoten)…"
    psql "$DB_URL" -v ON_ERROR_STOP=1 -q -f supabase/DEPLOY-ALL-IN-ONE.sql
    ok "Migration selesai"

    FUNCS="$(psql "$DB_URL" -tAc "select count(*) from pg_proc where proname in ('void_payment','import_prospects_batch','analytics_campuses','register_partner','rotate_partner_code','delete_prospect','set_prospect_consent','outreach_eligibility','analytics_campaigns','resolve_campaign')" | tr -d '[:space:]')"
    COLS="$(psql "$DB_URL" -tAc "select count(*) from information_schema.columns where table_schema='public' and ((table_name='requests' and column_name in ('campus','stack','source','prospect_id','campaign_id')) or (table_name='prospects' and column_name='consent_status'))" | tr -d '[:space:]')"
    [ "$FUNCS" = "10" ] || fail "Verifikasi fungsi gagal: $FUNCS/10. Cek log Supabase."
    [ "$COLS" = "6" ] || fail "Verifikasi kolom gagal: $COLS/6."
    ok "Verifikasi database: 10 fungsi + 6 kolom baru"
    DB_STATUS="diterapkan + diverifikasi"
  fi
else
  step "4/7 Migration dilewati (--skip-db)"
  DB_STATUS="dilewati (--skip-db)"
fi

# ---------- 5. commit & push ----------
if ! $SKIP_PUSH; then
  step "5/7 Commit & push"
  if [ -n "$(git status --porcelain)" ]; then
    git add -A
    git commit -m "$COMMIT_MSG"
    ok "Commit: $(git log -1 --oneline)"
  else
    info "Tidak ada perubahan untuk di-commit."
  fi
  PUSH_OK=false
  PA=1
  while [ "$PA" -le 3 ]; do
    if git push origin main; then
      PUSH_OK=true
      break
    fi
    warn "Push gagal (percobaan ${PA}/3)."
    PA=$((PA + 1))
    [ "$PA" -le 3 ] && sleep 5
  done
  $PUSH_OK || fail "Push ke origin/main gagal. Deploy dibatalkan agar kode & live tetap sinkron (atau pakai --skip-push)."
  ok "Push ke origin/main"
else
  step "5/7 Commit & push dilewati"
fi

# ---------- 6. deploy ----------
DEPLOY_URL=""
if ! $SKIP_DEPLOY; then
  step "6/7 Deploy Vercel (production)"
  LOG="$(mktemp)"
  ATTEMPT=1
  MAX_ATTEMPT=3
  SUCCESS=false
  while [ "$ATTEMPT" -le "$MAX_ATTEMPT" ]; do
    info "Percobaan ${ATTEMPT}/${MAX_ATTEMPT}"
    if vercel --prod --yes --archive=tgz >"$LOG" 2>&1; then
      SUCCESS=true
      break
    fi
    warn "Deploy gagal pada percobaan ${ATTEMPT}."
    ATTEMPT=$((ATTEMPT + 1))
    [ "$ATTEMPT" -le "$MAX_ATTEMPT" ] && sleep 5
  done

  tail -n 20 "$LOG" || true
  $SUCCESS || fail "Deploy gagal setelah ${MAX_ATTEMPT} percobaan. Log: ${LOG}"
  DEPLOY_URL="$(grep -Eo 'https://[A-Za-z0-9._-]+\.vercel\.app' "$LOG" | head -1 || true)"
  ok "Deploy selesai${DEPLOY_URL:+ · $DEPLOY_URL}"
  rm -f "$LOG"
else
  step "6/7 Deploy dilewati"
fi

# ---------- 7. smoke test ----------
if ! $SKIP_DEPLOY; then
  step "7/7 Smoke test produksi"
  info "Menunggu alias aktif…"
  sleep 3
  for path in $SMOKE_PATHS; do
    CODE=""
    i=1
    while [ "$i" -le 10 ]; do
      CODE="$(curl -s -o /dev/null -m 15 -w '%{http_code}' "$PROD_BASE$path" 2>/dev/null || true)"
      [ "$CODE" = "200" ] && break
      sleep 3
      i=$((i + 1))
    done
    if [ "$CODE" = "200" ]; then
      ok "$path → 200"
    else
      fail "Smoke test gagal: $path → ${CODE:-000}"
    fi
  done
else
  step "7/7 Smoke test dilewati"
fi

# ---------- ringkasan ----------
printf '\n%s%s╭──────────────────────────────────────────────╮%s\n' "$C_GREEN" "$C_BOLD" "$C_RESET"
printf '%s%s│              REDEPLOY SELESAI                │%s\n' "$C_GREEN" "$C_BOLD" "$C_RESET"
printf '%s%s╰──────────────────────────────────────────────╯%s\n' "$C_GREEN" "$C_BOLD" "$C_RESET"
printf '  Commit    : %s\n' "$(git log -1 --oneline 2>/dev/null || echo '-')"
printf '  Database  : %s\n' "$DB_STATUS"
printf '  Deploy    : %s\n' "${DEPLOY_URL:-dilewati}"
printf '  Live      : %s\n' "$PROD_BASE"

if [ "$DB_STATUS" = "TIDAK dijalankan (butuh DB URL)" ]; then
  printf '\n%s⚠ SQL belum dijalankan.%s Fitur CRM baru akan error sampai\n' "$C_YELLOW" "$C_RESET"
  printf '  supabase/DEPLOY-ALL-IN-ONE.sql dijalankan di Supabase SQL Editor.\n'
  printf '  Untuk otomatis: isi %s lalu jalankan make redeploy\n' "${DEPLOY_ENV_FILE/#$HOME/~}"
  printf '  (file: Supabase > Project Settings > Database > Connection string URI)\n'
fi

printf '\nRollback cepat:\n'
printf '  vercel rollback                  # kembali ke deployment sebelumnya\n'
printf '  git revert %s --no-edit && git push origin main\n' "$(git rev-parse --short HEAD 2>/dev/null || echo HEAD)"
