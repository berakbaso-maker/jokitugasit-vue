-- =============================================================
-- jokitugasit.my.id — Integritas referral
-- Jalankan SETELAH migration-import-batches.sql.
--
-- Mencegah self-referral: partner tidak mendapat komisi kalau nomor
-- WhatsApp klien sama dengan nomor WhatsApp partner (dinormalisasi:
-- buang non-digit, 0xxx -> 62xxx).
--
-- Guard ditegakkan di dua tempat:
--   1. create_public_request  -> kode tidak disimpan kalau self-referral
--   2. recompute_commission   -> tidak ada partner yang cocok, jadi
--      komisi tidak pernah dibuat walau kode sudah terlanjur tersimpan.
--
-- Additive & idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Normalisasi nomor telepon Indonesia
-- ---------------------------------------------------------------
create or replace function public.normalize_phone(p text)
returns text
language sql
immutable
as $$
  select case
    when d = '' then ''
    when left(d, 1) = '0' then '62' || substr(d, 2)
    when left(d, 2) = '62' then d
    else d
  end
  from (select regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g') as d) s;
$$;

revoke all on function public.normalize_phone(text) from public;
grant execute on function public.normalize_phone(text) to authenticated;

-- ---------------------------------------------------------------
-- 2. create_public_request: tolak atribusi ke nomor partner sendiri
-- ---------------------------------------------------------------
create or replace function public.create_public_request(
  p_customer_name text,
  p_whatsapp      text,
  p_description   text,
  p_category      text default 'web',
  p_deadline      text default 'besok',
  p_deadline_date date default null,
  p_link          text default null,
  p_file_url      text default null,
  p_email         text default null,
  p_referral_code text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_no text;
  v_ref      text;
  v_partner  public.partners%rowtype;
  v_attempt  int := 0;
begin
  if coalesce(trim(p_customer_name), '') = '' then
    raise exception 'NAMA_WAJIB' using errcode = '22023';
  end if;
  if coalesce(trim(p_whatsapp), '') = '' then
    raise exception 'WHATSAPP_WAJIB' using errcode = '22023';
  end if;
  if coalesce(trim(p_description), '') = '' then
    raise exception 'DESKRIPSI_WAJIB' using errcode = '22023';
  end if;
  if p_category not in ('web','mobile','desktop','database','ai','debug',
                        'skripsi','tugas_kuliah','design','lainnya') then
    raise exception 'KATEGORI_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_deadline not in ('hari_ini','besok','fleksibel') then
    raise exception 'DEADLINE_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_deadline = 'fleksibel' and p_deadline_date is null then
    raise exception 'TANGGAL_WAJIB' using errcode = '22023';
  end if;

  select * into v_partner
  from public.partners
  where referral_code = upper(trim(coalesce(p_referral_code, '')))
    and status = 'active';

  if found then
    -- Self-referral: kode dibuang, bukan disimpan lalu dibatalkan diam-diam.
    if public.normalize_phone(v_partner.whatsapp) = public.normalize_phone(p_whatsapp) then
      v_ref := null;
    else
      v_ref := v_partner.referral_code;
    end if;
  else
    v_ref := null;
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_order_no := 'JT' || lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
    begin
      insert into public.requests (
        order_no, customer_name, whatsapp, email, category, description,
        deadline, deadline_date, link, file_url, referral_code, source,
        status, quote_amount, internal_notes
      ) values (
        v_order_no,
        trim(p_customer_name),
        trim(p_whatsapp),
        nullif(trim(coalesce(p_email, '')), ''),
        p_category,
        trim(p_description),
        p_deadline,
        case when p_deadline = 'fleksibel' then p_deadline_date end,
        nullif(trim(coalesce(p_link, '')), ''),
        nullif(trim(coalesce(p_file_url, '')), ''),
        v_ref,
        case when v_ref is null then 'INBOUND' else 'REFERRAL' end,
        'new',
        null,
        null
      );
      return v_order_no;
    exception when unique_violation then
      if v_attempt >= 8 then
        raise exception 'GAGAL_MEMBUAT_ORDER' using errcode = '23505';
      end if;
    end;
  end loop;
end;
$$;

revoke all on function public.create_public_request(
  text, text, text, text, text, date, text, text, text, text
) from public;
grant execute on function public.create_public_request(
  text, text, text, text, text, date, text, text, text, text
) to anon, authenticated;

-- ---------------------------------------------------------------
-- 3. recompute_commission_internal: partner yang nomornya sama
--    dengan klien tidak pernah cocok
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

  select id into v_partner_id
  from public.partners
  where referral_code = upper(trim(coalesce(v_req.referral_code, '')))
    and status = 'active'
    and public.normalize_phone(whatsapp) <> public.normalize_phone(coalesce(v_req.whatsapp, ''));

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

revoke all on function public.recompute_commission_internal(uuid) from public;
