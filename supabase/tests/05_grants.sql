-- Mirror Supabase's default grants so RLS (not missing privileges)
-- is what the security tests actually exercise.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
grant execute on all functions in schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
