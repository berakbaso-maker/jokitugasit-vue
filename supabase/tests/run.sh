#!/usr/bin/env bash
# =============================================================
# Jalankan seluruh migration + test SQL terhadap PostgreSQL lokal.
#
#   ./supabase/tests/run.sh
#
# Butuh `psql` dan server PostgreSQL yang sedang jalan.
# Database test dibuat ulang setiap kali supaya hasilnya deterministik.
# =============================================================
set -euo pipefail

DB="${TEST_DB:-jokitugasit_test}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
PSQL=(psql -v ON_ERROR_STOP=1 -q -X)

c_reset=$'\033[0m'; c_green=$'\033[38;5;82m'; c_red=$'\033[38;5;196m'; c_gray=$'\033[38;5;244m'

echo "${c_gray}recreating database ${DB}${c_reset}"
dropdb --if-exists "$DB"
createdb "$DB"

run() {
  local label="$1" file="$2"
  printf '  %-52s' "$label"
  if "${PSQL[@]}" -d "$DB" -f "$file" >/tmp/jt_test_out 2>&1; then
    echo "ok"
  else
    echo "FAIL"
    sed 's/^/      /' /tmp/jt_test_out
    exit 1
  fi
}

echo "migrations"
run "00_harness"                       "$DIR/00_harness.sql"
run "schema.sql"                       "$ROOT/schema.sql"
run "ig-schema.sql"                    "$ROOT/ig-schema.sql"
run "migration-referral-partner"       "$ROOT/migration-referral-partner.sql"
run "migration-delivery-walkthrough"   "$ROOT/migration-delivery-walkthrough.sql"
run "migration-security-hardening"     "$ROOT/migration-security-hardening.sql"
run "migration-outreach-schema"        "$ROOT/migration-outreach-schema.sql"
run "migration-money-schema"           "$ROOT/migration-money-schema.sql"
run "migration-payment-flow"           "$ROOT/migration-payment-flow.sql"
run "migration-analytics-source"       "$ROOT/migration-analytics-source.sql"
run "migration-import-batches"        "$ROOT/migration-import-batches.sql"
run "migration-referral-integrity"    "$ROOT/migration-referral-integrity.sql"
run "migration-data-rights"           "$ROOT/migration-data-rights.sql"
run "migration-project-details"       "$ROOT/migration-project-details.sql"
run "migration-hardening"             "$ROOT/migration-hardening.sql"
run "05_grants (supabase default)"     "$DIR/05_grants.sql"

echo "tests"
run "10_security.sql"                  "$DIR/10_security.sql"
run "20_outreach.sql"                  "$DIR/20_outreach.sql"
run "30_money.sql"                     "$DIR/30_money.sql"
run "40_partner_portal.sql"            "$DIR/40_partner_portal.sql"
run "50_payment_flow.sql"              "$DIR/50_payment_flow.sql"
run "60_analytics_source.sql"          "$DIR/60_analytics_source.sql"
run "70_import_batch.sql"              "$DIR/70_import_batch.sql"
run "80_referral_integrity.sql"        "$DIR/80_referral_integrity.sql"
run "90_data_rights.sql"               "$DIR/90_data_rights.sql"
run "95_project_details.sql"           "$DIR/95_project_details.sql"
run "99_hardening.sql"                 "$DIR/99_hardening.sql"

echo
echo "${c_green}semua migration + test lulus${c_reset}"
