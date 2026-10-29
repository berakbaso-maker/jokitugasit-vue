-- =============================================================
-- jokitugasit.my.id — Money & commission schema
-- Urutan: jalankan SETELAH migration-security-hardening.sql.
--
-- Menggantikan `requests.commission_paid` (boolean, tanpa audit) dengan
-- tabel commissions yang:
--   * menyimpan nominal sebagai bigint rupiah (tidak ada float),
--   * hanya menjadi ELIGIBLE setelah pembayaran lunas (DP tidak dihitung),
--   * tidak bisa dihitung ganda walau ada dua baris pembayaran,
--   * idempoten lewat idempotency_key pada payments.
-- =============================================================

-- ---------------------------------------------------------------
-- 0. Prasyarat: kolom dari migration-referral-partner.sql
--    (dibuat defensif supaya file ini aman dijalankan di database
--    yang mungkin belum menjalankan migration tersebut)
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists referral_code text,
  add column if not exists email text,
  add column if not exists commission_paid boolean default false;

create index if not exists idx_requests_referral_code on public.requests (referral_code);

-- ---------------------------------------------------------------
-- 1. quote_amount jadi integer rupiah
-- ---------------------------------------------------------------
alter table public.requests
  alter column quote_amount type bigint using round(coalesce(quote_amount, 0))::bigint;

alter table public.requests
  add column if not exists discount_amount bigint not null default 0
    check (discount_amount >= 0);

-- Engineer perlu bisa membuat proyek dari dashboard (policy lama hanya
-- mengizinkan SELECT/UPDATE).
drop policy if exists "requests_engineer_insert" on public.requests;
create policy "requests_engineer_insert"
  on public.requests for insert
  to authenticated
  with check (public.is_engineer());

-- ---------------------------------------------------------------
-- 2. payments
-- ---------------------------------------------------------------
create table if not exists public.payments (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid not null references public.requests (id) on delete restrict,
  kind            text not null check (kind in ('DP','SETTLEMENT','REFUND')),
  amount          bigint not null check (amount > 0),
  status          text not null default 'CONFIRMED'
                  check (status in ('PENDING','CONFIRMED','VOID')),
  method          text,
  proof_url       text,
  idempotency_key text unique,
  paid_at         timestamptz,
  note            text,
  created_at      timestamptz not null default now()
);

create index if not exists payments_request_idx on public.payments (request_id, status);

-- ---------------------------------------------------------------
-- 3. commissions
-- ---------------------------------------------------------------
create table if not exists public.commissions (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid not null unique references public.requests (id) on delete restrict,
  partner_id      uuid not null references public.partners (id) on delete restrict,
  eligible_amount bigint not null default 0 check (eligible_amount >= 0),
  rate_bps        int not null default 1000 check (rate_bps between 0 and 10000),
  amount          bigint generated always as ((eligible_amount * rate_bps) / 10000) stored,
  status          text not null default 'PENDING'
                  check (status in ('PENDING','ELIGIBLE','PAID','VOID','ADJUSTMENT')),
  paid_at         timestamptz,
  payment_proof   text,
  note            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- PAID wajib punya bukti waktu bayar
  constraint commissions_paid_has_timestamp check (
    status <> 'PAID' or paid_at is not null
  )
);

create index if not exists commissions_partner_idx on public.commissions (partner_id, status);
create index if not exists commissions_status_idx on public.commissions (status, created_at desc);

-- Satu proyek hanya boleh punya satu attribution partner.
create unique index if not exists commissions_one_per_request
  on public.commissions (request_id);

-- ---------------------------------------------------------------
-- 4. Hitung ulang komisi dari pembayaran yang benar-benar CONFIRMED
-- ---------------------------------------------------------------
-- Inti perhitungan. Tidak diekspos ke PostgREST; hanya dipanggil oleh
-- wrapper berizin di bawah atau oleh migration/backfill.
create or replace function public.recompute_commission_internal(p_request_id uuid)
returns public.commissions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req        public.requests%rowtype;
  v_partner_id uuid;
  v_paid       bigint;
  v_refunded   bigint;
  v_total      bigint;
  v_eligible   bigint;
  v_row        public.commissions%rowtype;
begin
  select * into v_req from public.requests where id = p_request_id;
  if not found then
    raise exception 'PROYEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;

  select id into v_partner_id
  from public.partners
  where referral_code = upper(trim(coalesce(v_req.referral_code, '')))
    and status = 'active';

  -- Tanpa partner aktif: tidak ada komisi, dan baris lama (jika ada) dibatalkan.
  if v_partner_id is null then
    update public.commissions
       set status = 'VOID', eligible_amount = 0, updated_at = now()
     where request_id = p_request_id
       and status in ('PENDING','ELIGIBLE');
    select * into v_row from public.commissions where request_id = p_request_id;
    return v_row;
  end if;

  select coalesce(sum(amount), 0) into v_paid
  from public.payments
  where request_id = p_request_id and status = 'CONFIRMED' and kind <> 'REFUND';

  select coalesce(sum(amount), 0) into v_refunded
  from public.payments
  where request_id = p_request_id and status = 'CONFIRMED' and kind = 'REFUND';

  v_total := greatest(coalesce(v_req.quote_amount, 0) - coalesce(v_req.discount_amount, 0), 0);

  -- DP / pembayaran sebagian TIDAK membuat komisi eligible.
  -- Refund mengurangi nilai yang dikomisikan, bukan membatalkan seluruh
  -- komisi (kecuali refund-nya memang menutup seluruh nilai transaksi).
  if v_total > 0 and v_paid >= v_total then
    v_eligible := greatest(v_total - v_refunded, 0);
  else
    v_eligible := 0;
  end if;

  insert into public.commissions (request_id, partner_id, eligible_amount, status)
  values (p_request_id, v_partner_id, v_eligible,
          case
            when v_eligible > 0 then 'ELIGIBLE'
            when v_refunded > 0 then 'VOID'
            else 'PENDING'
          end)
  on conflict (request_id) do update
    set partner_id = excluded.partner_id,
        status = case
                   -- Sudah dibayar: jangan pernah menurunkan status atau
                   -- menulis ulang nominal yang sudah dibayarkan. Kalau nilai
                   -- eligible berubah, tandai ADJUSTMENT untuk review manual.
                   when public.commissions.status = 'PAID' then
                     case when excluded.eligible_amount <> public.commissions.eligible_amount
                          then 'ADJUSTMENT' else 'PAID' end
                   when public.commissions.status = 'ADJUSTMENT' then 'ADJUSTMENT'
                   else excluded.status
                 end,
        eligible_amount = case
                            when public.commissions.status in ('PAID','ADJUSTMENT')
                              then public.commissions.eligible_amount
                            else excluded.eligible_amount
                          end,
        updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.recompute_commission_internal(uuid) from public;

create or replace function public.recompute_commission(p_request_id uuid)
returns public.commissions
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  return public.recompute_commission_internal(p_request_id);
end;
$$;

revoke all on function public.recompute_commission(uuid) from public;
grant execute on function public.recompute_commission(uuid) to authenticated;

-- ---------------------------------------------------------------
-- 5. Catat pembayaran (idempoten) lalu hitung ulang komisi
-- ---------------------------------------------------------------
create or replace function public.record_payment(
  p_request_id      uuid,
  p_kind            text,
  p_amount          bigint,
  p_idempotency_key text default null,
  p_method          text default null,
  p_proof_url       text default null,
  p_paid_at         timestamptz default now(),
  p_note            text default null
)
returns public.payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.payments%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if p_kind not in ('DP','SETTLEMENT','REFUND') then
    raise exception 'JENIS_PEMBAYARAN_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'NOMINAL_TIDAK_VALID' using errcode = '22023';
  end if;

  -- Idempotensi: kirim kunci yang sama dua kali -> kembalikan baris lama,
  -- jangan pernah menambah komisi dua kali.
  if p_idempotency_key is not null then
    select * into v_row from public.payments where idempotency_key = p_idempotency_key;
    if found then
      perform public.recompute_commission_internal(v_row.request_id);
      return v_row;
    end if;
  end if;

  insert into public.payments (request_id, kind, amount, status, method,
                               proof_url, idempotency_key, paid_at, note)
  values (p_request_id, p_kind, p_amount, 'CONFIRMED', p_method,
          p_proof_url, p_idempotency_key, p_paid_at, p_note)
  returning * into v_row;

  perform public.recompute_commission_internal(p_request_id);
  return v_row;
end;
$$;

revoke all on function public.record_payment(uuid, text, bigint, text, text, text, timestamptz, text) from public;
grant execute on function public.record_payment(uuid, text, bigint, text, text, text, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------
-- 6. Tandai komisi dibayar
-- ---------------------------------------------------------------
create or replace function public.mark_commission_paid(
  p_commission_id uuid,
  p_proof_url     text default null,
  p_note          text default null
)
returns public.commissions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.commissions%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  select * into v_row from public.commissions where id = p_commission_id for update;
  if not found then
    raise exception 'KOMISI_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  if v_row.status <> 'ELIGIBLE' then
    raise exception 'KOMISI_BELUM_ELIGIBLE: status % tidak bisa dibayar', v_row.status
      using errcode = '22023';
  end if;

  update public.commissions
     set status = 'PAID', paid_at = now(),
         payment_proof = p_proof_url, note = coalesce(p_note, note),
         updated_at = now()
   where id = p_commission_id
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.mark_commission_paid(uuid, text, text) from public;
grant execute on function public.mark_commission_paid(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------
-- 7. Sinkronkan kolom warisan supaya UI lama tidak menampilkan data palsu
-- ---------------------------------------------------------------
create or replace function public.sync_legacy_commission_flag()
returns trigger
language plpgsql
as $$
begin
  update public.requests
     set commission_paid = (new.status = 'PAID')
   where id = new.request_id;
  return new;
end;
$$;

drop trigger if exists commissions_sync_legacy_trg on public.commissions;
create trigger commissions_sync_legacy_trg
  after insert or update of status on public.commissions
  for each row execute function public.sync_legacy_commission_flag();

-- ---------------------------------------------------------------
-- 8. Backfill: proyek lama dengan referral_code
-- ---------------------------------------------------------------
do $$
declare
  v_req_id uuid;
begin
  for v_req_id in
    select id from public.requests
    where referral_code is not null and quote_amount is not null
  loop
    perform public.recompute_commission_internal(v_req_id);
  end loop;

  -- Data lama yang sudah ditandai commission_paid=true dianggap sudah dibayar.
  update public.commissions c
     set status = 'PAID', paid_at = coalesce(c.paid_at, now()),
         note = coalesce(c.note, 'backfill dari commission_paid')
    from public.requests req
   where req.id = c.request_id
     and req.commission_paid = true
     and c.status = 'ELIGIBLE';
end;
$$;

-- ---------------------------------------------------------------
-- 9. RLS
-- ---------------------------------------------------------------
alter table public.payments    enable row level security;
alter table public.commissions enable row level security;

drop policy if exists payments_engineer_all on public.payments;
create policy payments_engineer_all on public.payments
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

drop policy if exists commissions_engineer_all on public.commissions;
create policy commissions_engineer_all on public.commissions
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

create or replace function public.analytics_overview(
  p_from date default null,
  p_to   date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  return (
  with windowed_requests as (
    select * from public.requests
    where (p_from is null or created_at >= p_from)
      and (p_to   is null or created_at <  (p_to + 1))
  ),
  paid as (
    select coalesce(sum(amount), 0) as gross
    from public.payments
    where status = 'CONFIRMED' and kind <> 'REFUND'
  ),
  commission_totals as (
    select
      coalesce(sum(amount) filter (where status = 'PAID'), 0)     as paid,
      coalesce(sum(amount) filter (where status = 'ELIGIBLE'), 0) as unpaid
    from public.commissions
  )
  select jsonb_build_object(
    'target_accounts',    (select count(*) from public.target_accounts),
    'permission_granted', (select count(*) from public.target_accounts
                            where relationship_status = 'PERMISSION_GRANTED'),
    'prospects_total',    (select count(*) from public.prospects),
    'prospects_queue',    (select count(*) from public.prospects
                            where status in ('NEW','READY_TO_REVIEW')),
    'prospects_dnc',      (select count(*) from public.prospects where do_not_contact),
    'contacts_sent',      (select count(*) from public.outreach_logs where outcome = 'SENT'),
    'responses',          (select count(*) from public.outreach_logs
                            where outcome in ('REPLIED','INTERESTED_SERVICE',
                                              'INTERESTED_REFERRAL','NOT_INTERESTED')),
    'interested',         (select count(*) from public.outreach_logs
                            where outcome in ('INTERESTED_SERVICE','INTERESTED_REFERRAL')),
    'projects_total',     (select count(*) from windowed_requests),
    'projects_completed', (select count(*) from windowed_requests where status = 'paid'),
    'gross_confirmed',    (select gross from paid),
    'commission_paid',    (select paid from commission_totals),
    'commission_unpaid',  (select unpaid from commission_totals),
    'active_partners',    (select count(*) from public.partners where status = 'active'),
    'partners_with_deal', (select count(distinct partner_id) from public.commissions
                            where status in ('ELIGIBLE','PAID'))
  ));
end;
$$;

revoke all on function public.analytics_overview(date, date) from public;
grant execute on function public.analytics_overview(date, date) to authenticated;

create or replace function public.analytics_funnel(
  p_from date default null,
  p_to   date default null
)
returns table (
  stage    text,
  count    bigint,
  ordering int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  return query
  with base as (
    select * from public.outreach_logs
    where (p_from is null or sent_at >= p_from)
      and (p_to   is null or sent_at <  (p_to + 1))
  )
  select 'Dihubungi', count(*), 1 from base
  union all
  select 'Dibalas', count(*) filter (where outcome in
    ('REPLIED','INTERESTED_SERVICE','INTERESTED_REFERRAL','NOT_INTERESTED')), 2 from base
  union all
  select 'Berminat', count(*) filter (where outcome in
    ('INTERESTED_SERVICE','INTERESTED_REFERRAL')), 3 from base
  union all
  select 'Deal', (select count(*) from public.requests r
                  where r.status in ('working','review','done','paid')
                    and (p_from is null or r.created_at >= p_from)
                    and (p_to is null or r.created_at < (p_to + 1))), 4
  order by 3;
end;
$$;

revoke all on function public.analytics_funnel(date, date) from public;
grant execute on function public.analytics_funnel(date, date) to authenticated;

-- ---------------------------------------------------------------
-- 10b. Portal partner (publik, tapi hanya data partner itu sendiri)
-- ---------------------------------------------------------------
create or replace function public.partner_portal(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_partner public.partners%rowtype;
  v_code    text := upper(btrim(coalesce(p_code, '')));
begin
  select * into v_partner
  from public.partners
  where referral_code = v_code and status = 'active';

  if not found then return null; end if;

  return jsonb_build_object(
    'partner', jsonb_build_object(
      'full_name',     v_partner.full_name,
      'referral_code', v_partner.referral_code,
      'campus',        v_partner.campus,
      'status',        v_partner.status
    ),
    'stats', jsonb_build_object(
      'referral_count', count(*),
      'deal_count',     count(*) filter (where c.status in ('ELIGIBLE','PAID','ADJUSTMENT')),
      'total_paid',     coalesce(sum(c.amount) filter (where c.status = 'PAID'), 0),
      'total_pending',  coalesce(sum(c.amount) filter (where c.status = 'ELIGIBLE'), 0)
    ),
    'commissions', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'order_no',    r.order_no,
          'category',    r.category,
          'status',      c.status,
          'amount',      c.amount,
          'created_at',  c.created_at,
          'paid_at',     c.paid_at
        ) order by c.created_at desc
      ) filter (where c.id is not null),
      '[]'::jsonb
    )
  )
  from public.commissions c
  join public.requests r on r.id = c.request_id
  where c.partner_id = v_partner.id;
end;
$$;

revoke all on function public.partner_portal(text) from public;
grant execute on function public.partner_portal(text) to anon, authenticated;

-- ---------------------------------------------------------------
-- 11. Seed template DM
-- ---------------------------------------------------------------
insert into public.dm_templates (name, category, body, sort_order)
select * from (values
  ('Perkenalan ke admin angkatan', 'ADMIN',
   'Halo kak, izin perkenalan. Saya software engineer yang membuka jasa konsultasi coding, debugging, integrasi API/database, serta pengembangan software. Saya ingin memperkenalkan layanan ini kepada teman-teman mahasiswa IT di angkatan kakak. Saya juga menyediakan komisi referral 10% untuk rekomendasi yang berhasil menjadi klien. Apakah berkenan jika saya kirim website dan informasi singkatnya untuk dipertimbangkan atau dibagikan? Terima kasih, kak.', 1),
  ('Direct client + referral', 'DUAL_OFFER',
   'Halo kak, salam kenal! Saya software engineer dan sedang membuka jasa bantuan teknis coding, debugging, API/database, dan pengembangan aplikasi. Kalau kakak sedang butuh bantuan teknis atau punya teman yang membutuhkan, boleh menghubungi saya. Saya juga menyediakan komisi referral 10% untuk rekomendasi yang berhasil menjadi klien. Jika berkenan, boleh saya bagikan website dan portofolionya?', 2),
  ('Penjelasan skema referral', 'REFERRAL',
   'Terima kasih sudah tertarik, kak! Skemanya sederhana: kakak cukup merekomendasikan website/jasa saya kepada teman yang memang membutuhkan. Jika teman kakak jadi menggunakan jasa saya dan pembayarannya sudah lunas, kakak mendapatkan komisi 10% dari nilai transaksi setelah diskon. Seluruh pekerjaan teknis saya yang menangani. Kalau berkenan, nanti saya berikan kode referral khusus.', 3),
  ('Balasan setelah minta website', 'WEBSITE_REPLY',
   'Siap kak, ini website/portofolio saya: {website_url}. Silakan dilihat dulu. Kalau ada kendala teknis atau project yang mau didiskusikan, boleh cerita kebutuhan dan stack yang digunakan. Kalau ingin merekomendasikan ke teman, saya juga bisa buatkan kode referral.', 4),
  ('Penolakan / opt-out', 'OPT_OUT',
   'Baik kak, terima kasih sudah membalas. Saya tidak akan menghubungi lagi terkait penawaran ini. Semoga aktivitasnya lancar ya.', 5)
) as t(name, category, body, sort_order)
where not exists (select 1 from public.dm_templates);
