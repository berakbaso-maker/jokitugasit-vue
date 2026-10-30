#!/usr/bin/env bash
# Replay seluruh schema JokiTugasIT ke project Supabase baru lewat Management API.
#
# Pakai:
#   export SUPABASE_ACCESS_TOKEN=sbp_xxx        # PAT dengan scope All access
#   ./scripts/replay-migrations.sh <project-ref>
#
# Urutan mengikuti supabase/tests/run.sh:36-55 (otoritatif). Gagal di satu file
# = berhenti, supaya tidak ada schema setengah jadi.

set -euo pipefail

REF="${1:-}"
if [ -z "$REF" ]; then
  echo "usage: SUPABASE_ACCESS_TOKEN=sbp_... $0 <project-ref>" >&2
  exit 1
fi
if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  echo "SUPABASE_ACCESS_TOKEN belum di-set" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQLDIR="$ROOT/supabase"

FILE_URUT=(
  schema.sql
  ig-schema.sql
  migration-referral-partner.sql
  migration-delivery-walkthrough.sql
  migration-security-hardening.sql
  migration-outreach-schema.sql
  migration-money-schema.sql
  migration-payment-flow.sql
  migration-analytics-source.sql
  migration-import-batches.sql
  migration-referral-integrity.sql
  migration-data-rights.sql
  migration-project-details.sql
  migration-hardening.sql
  migration-consent-guard.sql
  migration-campaigns.sql
  migration-internal-platform.sql
  migration-testimonials.sql
)

jalankan() {
  local file="$1"
  local path="$SQLDIR/$file"
  if [ ! -f "$path" ]; then
    echo "LEWATI: $file tidak ada"
    return 0
  fi
  python3 - "$path" > /tmp/_q.json <<'PY'
import json, sys
print(json.dumps({"query": open(sys.argv[1], encoding='utf-8').read()}))
PY
  local code
  code=$(curl -s -X POST "https://api.supabase.com/v1/projects/$REF/database/query" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    --data-binary @/tmp/_q.json -o /tmp/_r.json -w '%{http_code}')
  if [ "$code" != "200" ] && [ "$code" != "201" ]; then
    echo "GAGAL  $file  http=$code"
    head -c 600 /tmp/_r.json; echo
    exit 1
  fi
  echo "OK     $file"
}

for f in "${FILE_URUT[@]}"; do
  jalankan "$f"
done

echo
echo "Selesai. Verifikasi:"
echo "  curl -s https://$REF.supabase.co/auth/v1/health -H \"apikey: <anon-key>\""
