#!/usr/bin/env bash
# ==============================================================================
# gate.sh — penjaga wajib sebelum commit/deploy.
#
#   make gate                 # statis + unit + DB + build
#   make gate ARGS="--static" # hanya cek statis (cepat)
#
# Exit non-zero = jangan commit / jangan deploy.
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_BLUE=$'\033[38;5;39m'
C_GREEN=$'\033[38;5;82m'; C_YELLOW=$'\033[38;5;220m'; C_RED=$'\033[38;5;196m'; C_GRAY=$'\033[38;5;244m'

step(){ printf '\n%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
ok(){ printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn(){ printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
info(){ printf '%s·%s %s\n' "$C_GRAY" "$C_RESET" "$*"; }
fail(){ printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; printf '\n%sGATE GAGAL%s — jangan commit/deploy.\n' "$C_RED" "$C_RESET" >&2; exit 1; }

usage(){
  cat <<'EOF'
Penggunaan: make gate [ARGS="..."]

Opsi:
  --static      Hanya cek statis (tanpa test & build)
  --skip-tests  Lewati unit test
  --skip-db     Lewati test database
  --skip-build  Lewati build
  -h, --help    Bantuan
EOF
}

STATIC_ONLY=false
SKIP_TESTS=false
SKIP_DB=false
SKIP_BUILD=false

while [ $# -gt 0 ]; do
  case "$1" in
    --static)     STATIC_ONLY=true ;;
    --skip-tests) SKIP_TESTS=true ;;
    --skip-db)    SKIP_DB=true ;;
    --skip-build) SKIP_BUILD=true ;;
    -h|--help)    usage; exit 0 ;;
    *) fail "Opsi tidak dikenal: $1" ;;
  esac
  shift
done

$STATIC_ONLY && SKIP_TESTS=true && SKIP_DB=true && SKIP_BUILD=true

CHECKS=0
pass(){ CHECKS=$((CHECKS + 1)); ok "$1"; }

# ---------------------------------------------------------------- 0. preflight
step "Gate — preflight"
command -v git >/dev/null 2>&1 || fail "git tidak ditemukan"
command -v node >/dev/null 2>&1 || fail "node tidak ditemukan"
command -v npm >/dev/null 2>&1 || fail "npm tidak ditemukan"
[ -f package.json ] || fail "package.json tidak ada — jalankan dari repo"
git rev-parse --git-dir >/dev/null 2>&1 || fail "bukan git repository"
pass "git, node $(node -v), npm $(npm -v)"

# ---------------------------------------------------------------- 1. diff check
step "Gate 1 — diff bersih"
if ! git diff --check >/tmp/jt_gate_diff 2>&1; then
  sed 's/^/  /' /tmp/jt_gate_diff
  fail "git diff --check menemukan whitespace/conflict marker"
fi
pass "tidak ada conflict marker / trailing whitespace"

# ---------------------------------------------------------------- 2. secret scan
step "Gate 2 — scan secret"
STAGED="$(git diff --cached --name-only || true)"
if [ -n "$STAGED" ]; then
  NAMES="$STAGED"
  DIFF="$(git diff --cached -U0 || true)"
  SCOPE="staged"
else
  NAMES="$(git diff --name-only || true)"
  DIFF="$(git diff -U0 || true)"
  SCOPE="working tree"
fi

# .env tidak boleh ikut ter-stage (kecuali .env.example)
if printf '%s\n' "$NAMES" | grep -E '(^|/)\.env($|\.)' | grep -qv '\.env\.example$'; then
  printf '%s\n' "$NAMES" | grep -E '(^|/)\.env($|\.)' | sed 's/^/  /'
  fail "file .env ikut ter-stage"
fi

# pola rahasia
if printf '%s' "$DIFF" | grep -nE 'eyJh''bGciOi|-----BEGIN [A-Z ]*PRIVATE KEY-----|SUPABASE_SERVICE_ROLE_KEY=[A-Za-z0-9._-]{20,}|IG_ACCESS_TOKEN=[A-Za-z0-9._-]{20,}|TELEGRAM_BOT_TOKEN=[0-9]{6,}:' >/tmp/jt_gate_sec 2>/dev/null; then
  sed -E 's/(.{160}).*/\1…/' /tmp/jt_gate_sec | sed 's/^/  /'
  fail "pola rahasia terdeteksi di $SCOPE"
fi

# URL Postgres berpassword hanya boleh di file non-dokumentasi (dan bukan placeholder)
# Dokumentasi & skrip automation berisi contoh/placeholder URL, bukan kredensial.
SUSPECT_FILES="$(printf '%s\n' "$NAMES" | grep -vE '\.(md|html)$' | grep -vE '^scripts/' || true)"
if [ -n "$SUSPECT_FILES" ]; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if grep -nE 'postgres(ql)?://[^[:space:]"<>]+:[^[:space:]"<>]+@' "$f" | grep -v '<PASSWORD>' >/dev/null 2>&1; then
      fail "connection string berpassword terdeteksi di $f"
    fi
  done <<< "$SUSPECT_FILES"
fi
# File baru yang belum di-stage tidak muncul di git diff — pindai terpisah.
UNTRACKED="$(git ls-files --others --exclude-standard || true)"
if [ -n "$UNTRACKED" ]; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    case "$f" in
      *.md|*.html|scripts/*) continue ;;
    esac
    if grep -nE 'eyJh''bGciOi|-----BEGIN [A-Z ]*PRIVATE KEY-----|SUPABASE_SERVICE_ROLE_KEY=[A-Za-z0-9._-]{20,}|IG_ACCESS_TOKEN=[A-Za-z0-9._-]{20,}' "$f" >/tmp/jt_gate_sec2 2>/dev/null; then
      printf '  %s\n' "$f"
      sed -E 's/(.{160}).*/\1…/' /tmp/jt_gate_sec2 | sed 's/^/    /'
      fail "pola rahasia terdeteksi di file untracked: $f"
    fi
  done <<< "$UNTRACKED"
fi
pass "tidak ada .env/JWT/service role/token di $SCOPE + untracked"

# ---------------------------------------------------------------- 3. file wajib
step "Gate 3 — aturan & dokumentasi"
[ -f AGENTS.md ] || fail "AGENTS.md hilang — aturan wajib repo tidak ada"
[ -f .opencode/skills/jokitugasit-production-gate/SKILL.md ] || fail "skill jokitugasit-production-gate hilang"
# Skill ini harus repo-scoped, bukan global.
if [ -d "$HOME/.config/opencode/skills/jokitugasit-production-gate" ]; then
  fail "skill ini terpasang di global (~/.config/opencode/skills) — harus khusus repo"
fi
if ! git remote get-url origin 2>/dev/null | grep -q 'jokitugasit-vue'; then
  fail "remote origin bukan jokitugasit-vue — gate ini hanya untuk repo ini"
fi
[ -f docs/OUTREACH-CRM.md ] || fail "docs/OUTREACH-CRM.md hilang"
[ -f docs/PRD-OUTREACH.md ] || fail "docs/PRD-OUTREACH.md hilang"
[ -f docs/DEPLOY.md ] || fail "docs/DEPLOY.md hilang"
pass "AGENTS.md, skill, dan 3 dokumen acuan ada"

# ---------------------------------------------------------------- 4. migration coverage
step "Gate 4 — cakupan migration & test"
MISSING=0
for f in supabase/migration-*.sql; do
  base="$(basename "$f")"
  [ "$base" = "migration-engineer-role.sql" ] && continue   # opsional, bukan bagian bundle
  if ! grep -q "$base" supabase/DEPLOY-ALL-IN-ONE.sql; then
    warn "migration tidak ada di DEPLOY-ALL-IN-ONE.sql: $base"
    MISSING=1
  fi
  if ! grep -q "$base" supabase/tests/run.sh; then
    warn "migration tidak dijalankan di supabase/tests/run.sh: $base"
    MISSING=1
  fi
done
[ "$MISSING" = "0" ] || fail "ada migration yang tidak tercakup bundle/test"

for f in supabase/tests/[0-9]*.sql; do
  base="$(basename "$f")"
  grep -q "$base" supabase/tests/run.sh || fail "test tidak terdaftar di run.sh: $base"
done
pass "semua migration & test terdaftar"

# ---------------------------------------------------------------- 5. bundle integrity
step "Gate 5 — integritas bundle SQL"
for fn in void_payment import_prospects_batch analytics_campuses register_partner rotate_partner_code delete_prospect set_prospect_consent outreach_eligibility analytics_campaigns resolve_campaign; do
  grep -q "function public\.${fn}" supabase/DEPLOY-ALL-IN-ONE.sql || fail "fungsi ${fn} tidak ada di bundle"
done
for col in campus stack source prospect_id consent_status campaign_id; do
  grep -qE "add column if not exists ${col}" supabase/DEPLOY-ALL-IN-ONE.sql || fail "kolom ${col} tidak ada di bundle"
done
pass "10 fungsi + 6 kolom kunci ada di bundle"

# ---------------------------------------------------------------- 6. unit test
if ! $SKIP_TESTS; then
  step "Gate 6 — unit test"
  npm test
  pass "unit test lulus"
else
  info "unit test dilewati"
fi

# ---------------------------------------------------------------- 7. DB test
if ! $SKIP_DB; then
  step "Gate 7 — database test"
  if command -v pg_isready >/dev/null 2>&1 && pg_isready -q 2>/dev/null; then
    npm run test:db
    pass "migration + RLS test lulus"
  else
    warn "PostgreSQL lokal tidak aktif — test DB dilewati (bukan bukti produksi aman)"
  fi
else
  info "test DB dilewati"
fi

# ---------------------------------------------------------------- 8. build
if ! $SKIP_BUILD; then
  step "Gate 8 — build"
  npm run build
  pass "build lulus"
else
  info "build dilewati"
fi

# ---------------------------------------------------------------- ringkasan
printf '\n%s%s╭──────────────────────────────────────────────╮%s\n' "$C_GREEN" "$C_BOLD" "$C_RESET"
printf '%s%s│                 GATE LULUS                   │%s\n' "$C_GREEN" "$C_BOLD" "$C_RESET"
printf '%s%s╰──────────────────────────────────────────────╯%s\n' "$C_GREEN" "$C_BOLD" "$C_RESET"
printf '  Pemeriksaan statis : %s\n' "$CHECKS"
printf '  Branch             : %s\n' "$(git rev-parse --abbrev-ref HEAD)"
printf '  Waktu              : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
printf '\nLanjut boleh. Jangan lupa: SQL dulu, frontend kemudian.\n'
