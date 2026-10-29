-- =============================================================
-- jokitugasit.my.id — Payment flow (Slice 1)
-- Jalankan SETELAH migration-money-schema.sql.
--
-- Tujuan:
--   1. Status proyek diturunkan dari tabel `payments`, bukan dari klik
--      "Mark as Paid" yang bisa berbohong.
--   2. Pembayaran yang salah input bisa dibatalkan (VOID) dengan alasan,
--      tanpa menghapus baris dan tanpa menghilangkan audit.
--   3. Data lama berstatus `paid` tanpa baris payments TIDAK disentuh
--      supaya tidak ada status historis yang tiba-tiba mundur.
--
-- Semua pernyataan additive/idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 0. Audit untuk pembatalan pembayaran
-- ---------------------------------------------------------------
alter table public.payments
  add column if not exists voided_at timestamptz,
  add column if not exists void_reason text;

-- ---------------------------------------------------------------
-- 1. Sinkronkan requests.status dengan pembayaran yang benar-benar ada
-- ---------------------------------------------------------------
-- Aturan:
--   * net = (pembayaran CONFIRMED selain REFUND) - (refund CONFIRMED)
--   * net >= total  -> 'paid'
--   * status sudah 'paid' tapi net < total dan proyek punya jejak
--     pembayaran -> 'working' (perlu tindakan manual untuk refund penuh;
--     status 'cancelled' belum ada di skema).
--   * proyek tanpa baris payments sama sekali tidak pernah diturunkan.
create or replace function public.sync_request_payment_status(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total    bigint;
  v_paid     bigint;
  v_refunded bigint;
  v_net      bigint;
  v_status   text;
  v_has_pay  boolean;
begin
  -- Boleh dipanggil engineer, atau proses server/migration (tanpa JWT).
  if auth.uid() is not null and not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  select greatest(coalesce(quote_amount, 0) - coalesce(discount_amount, 0), 0),
         status
    into v_total, v_status
  from public.requests
  where id = p_request_id;

  if not found then
    raise exception 'PROYEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;

  select coalesce(sum(amount) filter (where kind <> 'REFUND'), 0),
         coalesce(sum(amount) filter (where kind = 'REFUND'), 0),
         count(*) > 0
    into v_paid, v_refunded, v_has_pay
  from public.payments
  where request_id = p_request_id and status = 'CONFIRMED';

  v_net := greatest(v_paid - v_refunded, 0);

  if v_total > 0 and v_net >= v_total then
    update public.requests set status = 'paid'
     where id = p_request_id and status <> 'paid';
  elsif v_status = 'paid' and v_net < v_total and v_has_pay then
    update public.requests set status = 'working'
     where id = p_request_id and status = 'paid';
  end if;
end;
$$;

revoke all on function public.sync_request_payment_status(uuid) from public;

-- ---------------------------------------------------------------
-- 2. record_payment: perilaku lama + sinkron status
--    (idempotency_key tetap sama; DP tetap belum eligible)
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

  -- Idempotensi: kirim kunci yang sama dua kali -> kembalikan baris lama.
  if p_idempotency_key is not null then
    select * into v_row from public.payments where idempotency_key = p_idempotency_key;
    if found then
      perform public.recompute_commission_internal(v_row.request_id);
      perform public.sync_request_payment_status(v_row.request_id);
      return v_row;
    end if;
  end if;

  insert into public.payments (request_id, kind, amount, status, method,
                               proof_url, idempotency_key, paid_at, note)
  values (p_request_id, p_kind, p_amount, 'CONFIRMED', p_method,
          p_proof_url, p_idempotency_key, p_paid_at, p_note)
  returning * into v_row;

  perform public.recompute_commission_internal(p_request_id);
  perform public.sync_request_payment_status(p_request_id);
  return v_row;
end;
$$;

revoke all on function public.record_payment(uuid, text, bigint, text, text, text, timestamptz, text) from public;
grant execute on function public.record_payment(uuid, text, bigint, text, text, text, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------
-- 3. void_payment: koreksi salah input, bukan hapus data
-- ---------------------------------------------------------------
create or replace function public.void_payment(
  p_payment_id uuid,
  p_reason     text
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
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'ALASAN_WAJIB' using errcode = '22023';
  end if;

  select * into v_row from public.payments where id = p_payment_id for update;
  if not found then
    raise exception 'PEMBAYARAN_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  if v_row.status <> 'CONFIRMED' then
    raise exception 'PEMBAYARAN_TIDAK_AKTIF: status % tidak bisa dibatalkan', v_row.status
      using errcode = '22023';
  end if;

  update public.payments
     set status = 'VOID',
         voided_at = now(),
         void_reason = btrim(p_reason)
   where id = p_payment_id
  returning * into v_row;

  perform public.recompute_commission_internal(v_row.request_id);
  perform public.sync_request_payment_status(v_row.request_id);

  return v_row;
end;
$$;

revoke all on function public.void_payment(uuid, text) from public;
grant execute on function public.void_payment(uuid, text) to authenticated;

-- ---------------------------------------------------------------
-- 4. Backfill defensif: proyek yang sudah punya pembayaran penuh tapi
--    statusnya belum 'paid' (mis. diinput sebelum migration ini).
--    Tidak menyentuh proyek tanpa baris payments.
-- ---------------------------------------------------------------
do $$
declare
  v_id uuid;
begin
  for v_id in
    select distinct request_id from public.payments where status = 'CONFIRMED'
  loop
    perform public.sync_request_payment_status(v_id);
  end loop;
end;
$$;
