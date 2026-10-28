-- jokitugasit.my.id — Enforce engineer-only access
-- Jalankan di Supabase SQL Editor.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    case
      when new.raw_user_meta_data->>'role' = 'engineer' then 'engineer'
      else 'customer'
    end
  );
  return new;
end;
$$;

-- Contoh menjadikan akun tertentu sebagai engineer:
-- update public.profiles
-- set role = 'engineer'
-- where email = 'email-engineer@example.com';
