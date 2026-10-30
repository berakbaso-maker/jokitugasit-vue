-- =============================================================
-- Test: tabel testimonials (RLS + constraint)
-- =============================================================
set client_min_messages to warning;

-- ---------- rating di luar 1..5 harus ditolak ----------
do $$
begin
  begin
    insert into public.testimonials (name, rating, message)
    values ('Rating Salah', 9, 'harus ditolak');
    raise exception 'FAIL: rating 9 seharusnya ditolak check constraint';
  exception
    when check_violation then null;  -- sesuai harapan
  end;
end $$;

-- ---------- anon tidak boleh menerbitkan sendiri ----------
set role anon;
do $$
begin
  begin
    insert into public.testimonials (name, rating, message, is_published)
    values ('Curang', 5, 'mau langsung terbit', true);
    raise exception 'FAIL: anon seharusnya tidak boleh insert is_published=true';
  exception
    when insufficient_privilege then null;  -- sesuai harapan (RLS)
  end;
end $$;

-- ---------- anon boleh mengirim, tapi hasilnya tidak terlihat ----------
insert into public.testimonials (name, rating, message, is_published)
values ('Pengirim', 5, 'menunggu review', false);

do $$
declare n int;
begin
  select count(*) into n from public.testimonials;
  if n <> 0 then
    raise exception 'FAIL: anon seharusnya tidak melihat testimoni unpublished, dapat % baris', n;
  end if;
end $$;

reset role;

-- ---------- setelah diterbitkan, anon bisa melihat ----------
update public.testimonials set is_published = true where name = 'Pengirim';

set role anon;
do $$
declare n int;
begin
  select count(*) into n from public.testimonials;
  if n <> 1 then
    raise exception 'FAIL: anon harusnya melihat 1 testimoni terbit, dapat %', n;
  end if;
end $$;
reset role;
