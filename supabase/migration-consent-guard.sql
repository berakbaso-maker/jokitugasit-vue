-- =============================================================
-- jokitugasit.my.id — Consent & outreach eligibility (V4, Slice A)
-- Jalankan SETELAH migration-hardening.sql.
--
-- Memisahkan "pernah ditemukan" dari "boleh dihubungi":
--   consent_status: UNKNOWN / OPTED_IN / OPTED_OUT
--   contact_permission_source: dari mana izin/relasi berasal
--   outreach_eligibility(): keputusan per channel, bukan satu boolean
--
-- Additive & idempoten.
-- =============================================================

alter table public.prospects
  add column if not exists consent_status text not null default 'UNKNOWN',
  add column if not exists contact_permission_source text,
  add column if not exists consent_at timestamptz;

do $$
begin
  alter table public.prospects
    add constraint prospects_consent_valid
    check (consent_status in ('UNKNOWN','OPTED_IN','OPTED_OUT'));
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table public.prospects
    add constraint prospects_consent_source_valid
    check (
      contact_permission_source is null
      or contact_permission_source in (
        'WEBSITE_FORM','INBOUND_IG_DM','ADMIN_PARTNER_SHARED_OPT_IN','MANUAL_CONTACT'
      )
    );
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------
-- Backfill hanya untuk baris yang belum punya sumber izin.
-- Tidak menimpa keputusan manual pada re-run.
-- ---------------------------------------------------------------
update public.prospects
   set consent_status = case
         when do_not_contact then 'OPTED_OUT'
         when permission_basis = 'INBOUND_OPT_IN' then 'OPTED_IN'
         else 'UNKNOWN'
       end,
       contact_permission_source = case permission_basis
         when 'INBOUND_OPT_IN' then 'WEBSITE_FORM'
         when 'ADMIN_SHARED_LIST' then 'ADMIN_PARTNER_SHARED_OPT_IN'
         else 'MANUAL_CONTACT'
       end,
       consent_at = case
         when do_not_contact then coalesce(do_not_contact_at, now())
         when permission_basis = 'INBOUND_OPT_IN' then coalesce(first_seen_at, now())
         else null
       end
 where contact_permission_source is null;

-- ---------------------------------------------------------------
-- Trigger: jaga konsistensi DNC <-> consent.
-- Nama trigger sengaja "consent" agar berjalan SEBELUM
-- prospects_guard_dnc_trg (urutan alfabetis).
-- ---------------------------------------------------------------
create or replace function public.prospects_guard_consent()
returns trigger
language plpgsql
as $$
begin
  -- Isi sumber izin dari provenance saat baris baru dibuat / belum diisi.
  if new.contact_permission_source is null then
    new.contact_permission_source := case new.permission_basis
      when 'INBOUND_OPT_IN' then 'WEBSITE_FORM'
      when 'ADMIN_SHARED_LIST' then 'ADMIN_PARTNER_SHARED_OPT_IN'
      else 'MANUAL_CONTACT'
    end;
  end if;

  -- Import opt-in jelas -> OPTED_IN (hanya saat belum pernah diputuskan).
  if tg_op = 'INSERT'
     and new.permission_basis = 'INBOUND_OPT_IN'
     and new.consent_status = 'UNKNOWN' then
    new.consent_status := 'OPTED_IN';
    new.consent_at := coalesce(new.consent_at, now());
  end if;

  -- DNC selalu berarti opt-out.
  if new.do_not_contact then
    new.consent_status := 'OPTED_OUT';
    new.consent_at := coalesce(new.consent_at, new.do_not_contact_at, now());
  elsif new.consent_status = 'OPTED_OUT'
        and (tg_op = 'INSERT' or old.consent_status is distinct from 'OPTED_OUT') then
    -- Opt-out baru menyalakan DNC; trigger DNC yang mengatur status.
    -- Kalau baris sudah OPTED_OUT dan seseorang mencoba mematikan DNC,
    -- biarkan trigger DNC yang menolak (jangan ditutupi di sini).
    new.do_not_contact := true;
    new.consent_at := coalesce(new.consent_at, now());
  elsif new.consent_status = 'OPTED_IN' then
    new.consent_at := coalesce(new.consent_at, now());
  end if;

  return new;
end;
$$;

drop trigger if exists prospects_guard_consent_trg on public.prospects;
create trigger prospects_guard_consent_trg
  before insert or update on public.prospects
  for each row execute function public.prospects_guard_consent();

-- ---------------------------------------------------------------
-- Kelayakan per channel
-- ---------------------------------------------------------------
create or replace function public.outreach_eligibility(
  p_prospect_id uuid,
  p_channel     text default 'MANUAL_DM'
)
returns table (eligible boolean, reason text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v public.prospects%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if p_channel not in ('MANUAL_DM','AUTOMATED_DM','INBOUND_REPLY','WHATSAPP') then
    raise exception 'CHANNEL_TIDAK_VALID' using errcode = '22023';
  end if;

  select * into v from public.prospects where id = p_prospect_id;
  if not found then
    return query select false, 'NOT_FOUND'::text;
    return;
  end if;

  if v.do_not_contact or v.consent_status = 'OPTED_OUT' then
    return query select false, 'OPTED_OUT'::text;
    return;
  end if;

  if p_channel = 'AUTOMATED_DM' and v.consent_status <> 'OPTED_IN' then
    return query select false, 'CONSENT_REQUIRED'::text;
    return;
  end if;

  return query select true, 'OK'::text;
end;
$$;

revoke all on function public.outreach_eligibility(uuid, text) from public;
grant execute on function public.outreach_eligibility(uuid, text) to authenticated;

-- ---------------------------------------------------------------
-- Ubah consent secara eksplisit (engineer)
-- ---------------------------------------------------------------
create or replace function public.set_prospect_consent(
  p_prospect_id uuid,
  p_status      text,
  p_source      text default 'MANUAL_CONTACT'
)
returns public.prospects
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.prospects%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if p_status not in ('UNKNOWN','OPTED_IN','OPTED_OUT') then
    raise exception 'STATUS_CONSENT_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_source not in ('WEBSITE_FORM','INBOUND_IG_DM','ADMIN_PARTNER_SHARED_OPT_IN','MANUAL_CONTACT') then
    raise exception 'SUMBER_IZIN_TIDAK_VALID' using errcode = '22023';
  end if;

  select * into v from public.prospects where id = p_prospect_id for update;
  if not found then
    raise exception 'PROSPEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;

  if p_status = 'OPTED_IN' and v.do_not_contact then
    raise exception 'DNC_AKTIF: lepas status jangan-dihubungi dulu (dengan alasan)' using errcode = '42501';
  end if;

  update public.prospects
     set consent_status = p_status,
         contact_permission_source = p_source,
         consent_at = now(),
         do_not_contact = case when p_status = 'OPTED_OUT' then true else do_not_contact end,
         do_not_contact_at = case
           when p_status = 'OPTED_OUT' then coalesce(do_not_contact_at, now())
           else do_not_contact_at
         end
   where id = p_prospect_id
  returning * into v;

  return v;
end;
$$;

revoke all on function public.set_prospect_consent(uuid, text, text) from public;
grant execute on function public.set_prospect_consent(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------
-- Lepas DNC: reset consent ke UNKNOWN (bukan OPTED_IN diam-diam)
-- ---------------------------------------------------------------
create or replace function public.clear_do_not_contact(
  p_prospect_id uuid,
  p_reason      text
)
returns public.prospects
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.prospects%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'ALASAN_WAJIB' using errcode = '22023';
  end if;

  select * into v_row from public.prospects where id = p_prospect_id for update;
  if not found then
    raise exception 'PROSPEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  if not v_row.do_not_contact then
    return v_row;
  end if;

  perform set_config('app.dnc_override', 'on', true);

  update public.prospects set
    do_not_contact        = false,
    do_not_contact_reason = null,
    do_not_contact_at     = null,
    status                = 'NEW',
    consent_status        = 'UNKNOWN',
    contact_permission_source = 'MANUAL_CONTACT',
    consent_at            = now()
  where id = p_prospect_id
  returning * into v_row;

  perform set_config('app.dnc_override', 'off', true);

  insert into public.outreach_logs (prospect_id, channel, outcome, note)
  values (p_prospect_id, 'OTHER', 'NO_RESPONSE',
          'DNC dilepas manual. Alasan: ' || btrim(p_reason));

  return v_row;
end;
$$;

revoke all on function public.clear_do_not_contact(uuid, text) from public;
grant execute on function public.clear_do_not_contact(uuid, text) to authenticated;
