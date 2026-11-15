-- Onboarding answers kept for insight (age range, where they heard of us, alarm reaction,
-- time until up, goal). Only the user can read/write their own row (existing RLS).
alter table public.profiles add column if not exists onboarding jsonb;
