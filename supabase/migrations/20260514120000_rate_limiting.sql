-- Rate-limiting + server-side tier tracking for the RowanAI edge functions.
--
-- Why this exists:
--   Until this migration, free-tier limits were enforced client-side via
--   UserDefaults in StoreManager.swift. Those counters reset on reinstall and
--   are trivial to bypass on a jailbroken device. The cyrano / eleven /
--   livekit-token edge functions had per-call caps (max_tokens, voice
--   allowlist, body size) but zero per-user volume limits — a single
--   determined caller with the publishable anon key could rack up arbitrary
--   Anthropic / ElevenLabs / LiveKit charges against the project owner.
--
--   `usage_events` records one row per accepted call. The rate-limit helper
--   counts recent rows in the (user_id, endpoint) bucket and rejects the
--   call if it would exceed the per-minute / per-day / per-hour limit for
--   the caller's tier. `subscriptions` mirrors StoreKit entitlement so the
--   helper knows which tier's limit to apply.
--
-- Access model:
--   Both tables have RLS enabled with NO policies. That means only the
--   service role can read or write. Edge functions use the service role
--   internally (via the SERVICE_ROLE_KEY env var) so they work as expected.
--   The iOS client cannot touch these tables directly with its anon or
--   authenticated JWT — which is what we want.

-- =====================================================================
-- usage_events — one row per accepted API call.
-- =====================================================================

create table if not exists public.usage_events (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null,
  endpoint   text        not null,
  created_at timestamptz not null default now()
);

-- Hot path: count rows for (user_id, endpoint) in the last N minutes/hours/days.
-- Descending created_at lets the query short-circuit on the most recent rows.
create index if not exists idx_usage_events_user_endpoint_time
  on public.usage_events (user_id, endpoint, created_at desc);

alter table public.usage_events enable row level security;
-- Intentionally no policies — service_role bypasses RLS, every other role gets denied.

-- =====================================================================
-- subscriptions — server-side mirror of the user's StoreKit tier.
-- =====================================================================
--
-- The iOS app verifies entitlements via StoreKit 2's Transaction.currentEntitlements
-- (see StoreManager.checkEntitlements). After a successful purchase or restore,
-- a future client endpoint should POST the tier to a `set-tier` edge function
-- that writes here. For v1.0 every user defaults to 'free' — the wallet is
-- protected because the free limits are deliberately tight.

create table if not exists public.subscriptions (
  user_id    uuid        primary key,
  tier       text        not null default 'free'
                         check (tier in ('free', 'pro', 'pro_plus')),
  updated_at timestamptz not null default now()
);

alter table public.subscriptions enable row level security;
-- Same access model — service_role only.

-- Auto-update updated_at on tier changes.
create or replace function public.subscriptions_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_subscriptions_updated_at on public.subscriptions;
create trigger trg_subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.subscriptions_set_updated_at();
