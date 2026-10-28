-- Instagram operations schema for jokitugasit.my.id.
-- Run after supabase/schema.sql in Supabase SQL Editor.

create table if not exists public.ig_events (
  id uuid primary key default gen_random_uuid(),
  external_id text,
  event_type text not null,
  sender_id text,
  username text,
  message text,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (event_type, external_id)
);

create table if not exists public.ig_leads (
  id uuid primary key default gen_random_uuid(),
  ig_user_id text unique not null,
  username text,
  source text not null default 'comment' check (source in ('comment','mention','dm','manual')),
  category text,
  status text not null default 'new' check (status in ('new','contacted','qualified','converted','ignored')),
  last_message text,
  last_event_at timestamptz not null default now(),
  request_id uuid references public.requests (id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ig_messages (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.ig_leads (id) on delete cascade,
  external_id text unique,
  direction text not null check (direction in ('inbound','outbound')),
  message text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ig_posts (
  id uuid primary key default gen_random_uuid(),
  caption text not null default '',
  media_url text not null,
  media_type text not null default 'IMAGE' check (media_type in ('IMAGE','REELS')),
  status text not null default 'draft' check (status in ('draft','scheduled','publishing','published','failed')),
  scheduled_at timestamptz,
  published_at timestamptz,
  container_id text,
  instagram_media_id text,
  error_message text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ig_insights (
  id uuid primary key default gen_random_uuid(),
  snapshot_date date unique not null,
  followers_count integer not null default 0,
  media_count integer not null default 0,
  reach integer not null default 0,
  profile_views integer not null default 0,
  website_clicks integer not null default 0,
  raw_metrics jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists ig_events_created_at_idx on public.ig_events (created_at desc);
create index if not exists ig_leads_status_idx on public.ig_leads (status, last_event_at desc);
create index if not exists ig_posts_due_idx on public.ig_posts (status, scheduled_at);

alter table public.ig_events enable row level security;
alter table public.ig_leads enable row level security;
alter table public.ig_messages enable row level security;
alter table public.ig_posts enable row level security;
alter table public.ig_insights enable row level security;

create or replace function public.is_engineer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'engineer');
$$;

drop policy if exists "ig_events_engineer_select" on public.ig_events;
drop policy if exists "ig_leads_engineer_select" on public.ig_leads;
drop policy if exists "ig_leads_engineer_update" on public.ig_leads;
drop policy if exists "ig_messages_engineer_select" on public.ig_messages;
drop policy if exists "ig_posts_engineer_all" on public.ig_posts;
drop policy if exists "ig_insights_engineer_select" on public.ig_insights;

create policy "ig_events_engineer_select" on public.ig_events for select to authenticated using (public.is_engineer());
create policy "ig_leads_engineer_select" on public.ig_leads for select to authenticated using (public.is_engineer());
create policy "ig_leads_engineer_update" on public.ig_leads for update to authenticated using (public.is_engineer()) with check (public.is_engineer());
create policy "ig_messages_engineer_select" on public.ig_messages for select to authenticated using (public.is_engineer());
create policy "ig_posts_engineer_all" on public.ig_posts for all to authenticated using (public.is_engineer()) with check (public.is_engineer());
create policy "ig_insights_engineer_select" on public.ig_insights for select to authenticated using (public.is_engineer());

-- Backend functions use SUPABASE_SERVICE_ROLE_KEY, which bypasses RLS.
