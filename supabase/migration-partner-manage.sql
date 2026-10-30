-- =============================================================
-- Kelola partner & komisi dari dashboard
-- =============================================================
-- Isi:
--   1. requests.referral_partner_id  → atribusi permanen per order
--   2. trigger pengisi referral_partner_id dari referral_code
--   3. partner_summary(from,to)      → rekap per partner (engineer only)
--   4. partner_detail(id,from,to)    → order + komisi satu partner
--   5. set_partner_code(id,code)     → kode custom (validasi + unik)
--   6. recompute_commission_internal → pakai referral_partner_id lebih dulu
--
-- Kenapa (1)+(6) penting: versi lama mencari partner lewat
-- partners.referral_code = requests.referral_code AND status='active'.
-- Begitu kode dirotasi atau partner dinonaktifkan, order lamanya tidak lagi
-- menemukan partner → komisi jadi VOID saat dihitung ulang.

-- ---------------------------------------------------------------
-- 1. Kolom atribusi permanen
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists referral_partner_id uuid references public.partners (id);

update public.requests r
   set referral_partner_id = p.id
  from public.partners p
 where r.referral_partner_id is null
   and p.referral_code = upper(trim(coalesce(r.referral_code, '')));

create index if not exists requests_referral_partner_idx
  on public.requests (referral_partner_id);

-- ---------------------------------------------------------------
-- 2. Trigger: order baru otomatis mengikat partner
-- ---------------------------------------------------------------
create or replace function public.requests_set_referral_partner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.referral_partner_id is null
     and new.referral_code is not null
     and trim(new.referral_code) <> '' then
    select id into new.referral_partner_id
      from public.partners
     where referral_code = upper(trim(new.referral_code))
     limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists requests_set_referral_partner_trg on public.requests;
create trigger requests_set_referral_partner_trg
  before insert or update of referral_code on public.requests
  for each row execute function public.requests_set_referral_partner();

-- ---------------------------------------------------------------
-- 3. Rekap per partner
-- ---------------------------------------------------------------
create or replace function public.partner_summary(p_from date default null, p_to date default null)
returns table (
  partner_id          uuid,
  referral_code       text,
  full_name           text,
  whatsapp            text,
  campus              text,
  status              text,
  referrals           bigint,
  deals               bigint,
  gross               numeric,
  commission_pending  numeric,
  commission_paid     numeric,
  last_referral_at    timestamptz
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
  select p.id,
         p.referral_code,
         p.full_name,
         p.whatsapp,
         p.campus,
         p.status,
         count(r.id)                                                        as referrals,
         count(c.id) filter (where c.status <> 'VOID')                       as deals,
         coalesce(sum(r.quote_amount), 0)                                    as gross,
         coalesce(sum(c.eligible_amount) filter (where c.status in ('PENDING','ELIGIBLE')), 0) as commission_pending,
         coalesce(sum(coalesce(c.amount, c.eligible_amount)) filter (where c.status = 'PAID'), 0) as commission_paid,
         max(r.created_at)                                                   as last_referral_at
    from public.partners p
    left join public.requests r
           on r.referral_partner_id = p.id
          and (p_from is null or r.created_at >= p_from)
          and (p_to   is null or r.created_at <  (p_to + 1))
    left join public.commissions c on c.request_id = r.id
   group by p.id, p.referral_code, p.full_name, p.whatsapp, p.campus, p.status
   order by count(r.id) desc, p.created_at desc;
end;
$$;

revoke all on function public.partner_summary(date, date) from public, anon;
grant execute on function public.partner_summary(date, date) to authenticated;

-- ---------------------------------------------------------------
-- 4. Detail satu partner (maks 200 order)
-- ---------------------------------------------------------------
create or replace function public.partner_detail(p_partner_id uuid, p_from date default null, p_to date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_hasil jsonb;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'partner', (select to_jsonb(x) from public.partners x where x.id = p_partner_id),
    'orders', coalesce((
      select jsonb_agg(jsonb_build_object(
               'order_no', q.order_no,
               'customer_name', q.customer_name,
               'status', q.status,
               'quote_amount', q.quote_amount,
               'created_at', q.created_at,
               'commission', (select to_jsonb(c) from public.commissions c where c.request_id = q.id)
             ) order by q.created_at desc)
        from (
          select * from public.requests r
           where r.referral_partner_id = p_partner_id
             and (p_from is null or r.created_at >= p_from)
             and (p_to   is null or r.created_at <  (p_to + 1))
           order by r.created_at desc
           limit 200
        ) q
    ), '[]'::jsonb)
  ) into v_hasil;

  return v_hasil;
end;
$$;

revoke all on function public.partner_detail(uuid, date, date) from public, anon;
grant execute on function public.partner_detail(uuid, date, date) to authenticated;

-- ---------------------------------------------------------------
-- 5. Kode custom
-- ---------------------------------------------------------------
create or replace function public.set_partner_code(p_partner_id uuid, p_code text)
returns public.partners
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_row  public.partners%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  v_code := upper(trim(coalesce(p_code, '')));
  if v_code !~ '^REF-[A-Z0-9][A-Z0-9-]{2,15}$' then
    raise exception 'KODE_TIDAK_VALID' using errcode = '22023';
  end if;
  if exists (select 1 from public.partners where referral_code = v_code and id <> p_partner_id) then
    raise exception 'KODE_SUDAH_DIPAKAI' using errcode = '23505';
  end if;

  update public.partners set referral_code = v_code where id = p_partner_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'PARTNER_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

revoke all on function public.set_partner_code(uuid, text) from public, anon;
grant execute on function public.set_partner_code(uuid, text) to authenticated;

-- ---------------------------------------------------------------
-- 6. recompute_commission_internal: atribusi permanen
-- ---------------------------------------------------------------
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

  -- 1) Atribusi permanen menang: kode boleh diganti, partner boleh nonaktif.
  select id into v_partner_id
    from public.partners
   where id = v_req.referral_partner_id;

  -- 2) Fallback order lama (sebelum kolom ini ada) + cegah self-referral.
  if v_partner_id is null then
    select id into v_partner_id
      from public.partners
     where referral_code = upper(trim(coalesce(v_req.referral_code, '')))
       and status = 'active'
       and public.normalize_phone(whatsapp) <> public.normalize_phone(coalesce(v_req.whatsapp, ''));

    if v_partner_id is not null then
      update public.requests set referral_partner_id = v_partner_id where id = p_request_id;
    end if;
  else
    -- self-referral tetap ditolak walau id sudah tertanam
    if exists (
      select 1 from public.partners
       where id = v_partner_id
         and public.normalize_phone(whatsapp) = public.normalize_phone(coalesce(v_req.whatsapp, ''))
    ) then
      v_partner_id := null;
    end if;
  end if;

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

revoke all on function public.recompute_commission_internal(uuid) from public, anon, authenticated;
grant execute on function public.recompute_commission_internal(uuid) to service_role;
