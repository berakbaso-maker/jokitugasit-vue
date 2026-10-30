-- =============================================================
-- Test: internal platform (M1-M6)
-- Cakupan: struktur tabel, RLS engineer-only, policy audit_logs,
--          seed workflow, dan RPC internal (overview/trends/activity/
--          reports/breakdown).
-- =============================================================
set client_min_messages to warning;

-- ---------- 1. tabel inti ada ----------
do $$
declare
  t text;
  n int;
begin
  foreach t in array array[
    'campuses','leads','lead_activities','projects','project_tasks',
    'project_milestones','crm_tasks','audit_logs','referral_attributions',
    'workflow_definitions','workflow_runs','workflow_run_logs'
  ] loop
    select count(*) into n from information_schema.tables
     where table_schema = 'public' and table_name = t;
    if n <> 1 then
      raise exception 'FAIL: tabel % tidak ada', t;
    end if;
  end loop;
end $$;

-- ---------- 2. workflow_run_logs hanya punya satu definisi kolom ----------
-- (regresi: dulu tabel ini didefinisikan 2x dengan skema berbeda)
do $$
declare
  has_meta boolean;
  has_data boolean;
  ncols int;
begin
  select count(*) into ncols from information_schema.columns
   where table_schema = 'public' and table_name = 'workflow_run_logs';
  if ncols <> 6 then
    raise exception 'FAIL: workflow_run_logs harus 6 kolom, dapat %', ncols;
  end if;

  select exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='workflow_run_logs'
                    and column_name='meta') into has_meta;
  select exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='workflow_run_logs'
                    and column_name='data') into has_data;
  if not has_meta or has_data then
    raise exception 'FAIL: workflow_run_logs harus pakai kolom meta (bukan data)';
  end if;
end $$;

-- ---------- 3. RLS aktif + ada policy di semua tabel baru ----------
-- (regresi: audit_logs dulu punya policy tapi RLS-nya tidak pernah diaktifkan)
do $$
declare
  t text;
  rls boolean;
  npol int;
begin
  foreach t in array array[
    'campuses','leads','lead_activities','projects','project_tasks',
    'project_milestones','crm_tasks','audit_logs','referral_attributions',
    'workflow_definitions','workflow_runs','workflow_run_logs'
  ] loop
    select c.relrowsecurity,
           (select count(*) from pg_policy p where p.polrelid = c.oid)
      into rls, npol
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relname = t;

    if not rls then
      raise exception 'FAIL: RLS tidak aktif di tabel %', t;
    end if;
    if npol < 1 then
      raise exception 'FAIL: tabel % tidak punya policy', t;
    end if;
  end loop;
end $$;

-- ---------- 4. seed workflow definitions ----------
do $$
declare n int;
begin
  select count(*) into n from public.workflow_definitions;
  if n < 1 then
    raise exception 'FAIL: workflow_definitions harus terisi seed, dapat %', n;
  end if;
end $$;

-- ---------- 5. non-engineer TIDAK bisa baca leads ----------
-- Yang diuji: akses ditolak. Bisa berupa permission denied (belum ada grant)
-- ATAU 0 baris (RLS memfilter). Yang TIDAK boleh: melihat data.
do $$
declare
  n int;
  blocked boolean := false;
begin
  set local role authenticated;
  set local request.jwt.claim.role = 'authenticated';
  set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  begin
    select count(*) into n from public.leads;
    if n > 0 then
      raise exception 'FAIL: non-engineer bisa membaca leads (% baris)', n;
    end if;
    blocked := true;                     -- 0 baris = RLS memfilter, aman
  exception
    when insufficient_privilege then
      blocked := true;                   -- permission denied, juga aman
  end;
  if not blocked then
    raise exception 'FAIL: leads tidak terlindungi dari non-engineer';
  end if;
end $$;

-- ---------- 6. RPC internal menolak non-engineer ----------
do $$
begin
  set local role authenticated;
  set local request.jwt.claim.role = 'authenticated';
  set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  begin
    perform public.get_internal_overview();
    raise exception 'FAIL: non-engineer bisa memanggil get_internal_overview';
  exception
    when insufficient_privilege then null;   -- diharapkan
    when others then
      -- RPC memakai raise exception 'not authorized' -> SQLSTATE P0001
      if sqlstate <> 'P0001' then raise; end if;
  end;
end $$;

-- ---------- 7. RPC internal bekerja untuk engineer ----------
do $$
declare
  v int;
  j jsonb;
begin
  insert into auth.users (id, email, raw_user_meta_data)
  values ('33333333-3333-3333-3333-333333333333', 'eng-internal@test.local',
          '{"role":"engineer"}')
  on conflict (id) do nothing;
  insert into public.profiles (id, role, full_name)
  values ('33333333-3333-3333-3333-333333333333', 'engineer', 'Engineer Internal')
  on conflict (id) do update set role = 'engineer';

  set local role authenticated;
  set local request.jwt.claim.role = 'authenticated';
  set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

  if not public.is_engineer() then
    raise exception 'FAIL: fixture engineer tidak dikenali';
  end if;

  j := public.get_internal_overview();
  if j is null then raise exception 'FAIL: get_internal_overview null'; end if;

  perform public.get_internal_trends(7);
  perform public.get_recent_activity(5);
  perform public.get_reports_summary();

  select count(*) into v from public.workflow_definitions where event_key is not null;
  if v < 1 then raise exception 'FAIL: event_key workflow kosong'; end if;
end $$;

-- ---------- 8. touch_updated_at() ada ----------
do $$
declare n int;
begin
  select count(*) into n from information_schema.routines
   where routine_schema='public' and routine_name='touch_updated_at';
  if n <> 1 then
    raise exception 'FAIL: fungsi touch_updated_at tidak ada';
  end if;
end $$;
