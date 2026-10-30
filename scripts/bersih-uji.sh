#!/usr/bin/env bash
# Bersihkan sisa data uji (scripts/uji-supabase.mjs) langsung lewat DB.
# Harness tidak bisa menghapusnya sendiri: engineer sengaja TIDAK punya policy
# DELETE pada tabel requests/partners, jadi pembersihan butuh akses admin.
set -euo pipefail

SEKRET="${SEKRET:-$HOME/.hermes/secrets/jokitugasit-supabase-sg.env}"
# shellcheck disable=SC1090
. "$SEKRET"

export PGHOST="${PGHOST_OVERRIDE:-aws-0-ap-southeast-1.pooler.supabase.com}"
export PGPORT=5432
export PGDATABASE=postgres
export PGUSER="postgres.$SUPABASE_PROJECT_REF"
export PGSSLMODE=require
export PGCONNECT_TIMEOUT=15

psql -X -q -v ON_ERROR_STOP=1 <<'SQL'
begin;

delete from public.commissions
 where partner_id in (select id from public.partners where full_name like 'Uji%')
    or request_id in (select id from public.requests where customer_name like 'Uji%');

delete from public.referral_attributions
 where partner_id in (select id from public.partners where full_name like 'Uji%');

delete from public.payments
 where request_id in (select id from public.requests where customer_name like 'Uji%');

update public.requests set referral_partner_id = null
 where customer_name like 'Uji%';

delete from public.requests where customer_name like 'Uji%';
delete from public.partners  where full_name like 'Uji%';

delete from public.ig_leads   where username like 'uji%';
delete from public.ig_posts   where caption like 'uji%' or container_id like 'uji%';
delete from public.prospects  where ig_username like 'uji%' or display_name like 'Uji%';
delete from public.leads      where display_name like 'Uji%' or contact_ref like 'uji%';
delete from public.projects   where name like 'Uji%' or client_name like 'Uji%' or project_no like 'UJI%';
delete from public.campaigns  where name like 'Uji%';
delete from public.campuses   where university like '%Uji%' or community_name like 'Uji%';
delete from public.target_accounts where ig_username like 'uji%';
delete from public.dm_templates where name like 'Uji%';
delete from public.workflow_definitions where name like 'Uji%';
delete from public.import_batches where file_name like 'uji%';

commit;
SQL

echo "sisa data uji dibersihkan"
psql -X -tA -F': ' -c "
select 'requests', count(*) from public.requests
union all select 'partners', count(*) from public.partners
union all select 'commissions', count(*) from public.commissions
union all select 'payments', count(*) from public.payments"
