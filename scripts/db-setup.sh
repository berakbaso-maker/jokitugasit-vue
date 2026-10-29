#!/usr/bin/env bash
# ==============================================================================
# db-setup.sh — simpan connection string Supabase lalu jalankan migration.
#
#   make db-setup                 # tanya password/URI, simpan, lalu migrasi
#   make db-setup ARGS="--set-only"  # simpan saja, tanpa migrasi
#   SUPABASE_DB_URL="postgresql://..." make db-setup
#
# File disimpan di ~/.config/jokitugasit/db.env (chmod 600), bukan di repo.
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_BLUE=$'\033[38;5;39m'
C_GREEN=$'\033[38;5;82m'; C_YELLOW=$'\033[38;5;220m'; C_RED=$'\033[38;5;196m'

step(){ printf '\n%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
ok(){ printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn(){ printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
fail(){ printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

ENV_FILE="${DEPLOY_ENV_FILE:-$HOME/.config/jokitugasit/db.env}"
SET_ONLY=false
URL="${SUPABASE_DB_URL:-${DATABASE_URL:-}}"

while [ $# -gt 0 ]; do
  case "$1" in
    --set-only) SET_ONLY=true ;;
    --url) URL="${2:-}"; shift ;;
    -h|--help)
      cat <<'EOF'
Penggunaan: make db-setup [ARGS="..."]

  --set-only       Simpan connection string saja (tanpa migration)
  --url <uri>      Connection string (atau env SUPABASE_DB_URL)
  -h, --help       Bantuan

Ambil URI dari Supabase → Project Settings → Database → Connection string (URI).
File disimpan di ~/.config/jokitugasit/db.env (chmod 600).
EOF
      exit 0 ;;
    *) fail "Opsi tidak dikenal: $1" ;;
  esac
  shift
done

step "1/4 Periksa prasyarat"
command -v psql >/dev/null 2>&1 || fail "psql tidak ditemukan (brew install postgresql)."
[ -d .git ] || fail "Jalankan dari root repo."
ok "psql tersedia"

step "2/4 Connection string"
if [ -z "$URL" ]; then
  if [ -t 0 ]; then
    printf 'Tempel connection string Postgres (input tidak ditampilkan): '
    IFS= read -r -s URL
    printf '\n'
  else
    fail "Tidak ada TTY. Set SUPABASE_DB_URL atau pakai --url."
  fi
fi

URL="$(printf '%s' "$URL" | tr -d '\r' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
case "$URL" in
  postgres://*|postgresql://*) ;;
  *) fail "Format harus postgresql://... (bukan URL dashboard/anon key)." ;;
esac
case "$URL" in
  *'<PASSWORD>'*) fail "Password belum diganti (masih <PASSWORD>)." ;;
esac

psql "$URL" -tAc 'select 1' >/dev/null 2>&1 \
  || fail "Tidak bisa terhubung. Cek host/region, password, dan sslmode=require."

step "3/4 Simpan kredensial"
mkdir -p "$(dirname "$ENV_FILE")"
chmod 700 "$(dirname "$ENV_FILE")" 2>/dev/null || true
ESCAPED="$(printf '%s' "$URL" | sed "s/'/'\\\\''/g")"
umask 077
printf "SUPABASE_DB_URL='%s'\n" "$ESCAPED" > "$ENV_FILE"
chmod 600 "$ENV_FILE"
ok "Disimpan di ${ENV_FILE/#$HOME/~} (chmod 600)"
ok "Koneksi database: OK"

if $SET_ONLY; then
  step "4/4 Selesai (--set-only)"
  printf '\nJalankan migration: make db-push\n'
  exit 0
fi

step "4/4 Migration + verifikasi"
bash "$ROOT/scripts/redeploy.sh" --only-db
