-- =============================================================
-- jokitugasit.my.id — Delivery Walkthrough & Cheatsheet Migration
-- Menambahkan kolom delivery mentoring & video walkthrough
-- =============================================================

alter table public.requests
  add column if not exists walkthrough_url text,
  add column if not exists walkthrough_notes text,
  add column if not exists setup_instructions text;
