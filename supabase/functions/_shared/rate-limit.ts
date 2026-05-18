// Per-user rate limiting backed by the public.usage_events Postgres table.
//
// Edge functions call checkRateLimit() with the authenticated caller's
// user.sub (extracted from the verified Authorization JWT) and per-tier
// limits. The helper:
//   1. Looks up the caller's tier from public.subscriptions (default: 'free').
//   2. Counts recent rows in public.usage_events for (user_id, endpoint)
//      across per-minute / per-day / optional per-hour windows.
//   3. Optionally enforces a minimum spacing between calls.
//   4. Returns { allowed: true } and logs a row, OR { allowed: false }
//      with a 429-friendly user-facing message.
//
// This is the wallet-side defence. The iOS app's StoreManager also enforces
// these limits in the UI, but those counters can be reset by reinstalling —
// this layer cannot be bypassed because it runs in our infrastructure.
//
// Requires the `SERVICE_ROLE_KEY` env var (renamed from SUPABASE_SERVICE_ROLE_KEY
// because Supabase rejects secrets prefixed with SUPABASE_).

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export interface BucketLimits {
  perMinute: number;
  perDay: number;
  perHour?: number;
  minSpacingSeconds?: number;
}

export interface TierLimits {
  free: BucketLimits;
  pro:  BucketLimits;
}

export interface RateLimitResult {
  allowed: boolean;
  status?: number;
  message?: string;
}

// JWT payload claims we care about.
export interface JWTPayload {
  sub?: string;
  role?: string;
  exp?: number;
}

// =====================================================================
// JWT decode (signature already verified by Supabase verify_jwt = true).
// =====================================================================

export function decodeJWTPayload(authHeader: string | null): JWTPayload | null {
  if (!authHeader) return null;
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const padded = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(padded)) as JWTPayload;
  } catch {
    return null;
  }
}

// =====================================================================
// Supabase admin client (service-role).
// =====================================================================

let cachedAdmin: SupabaseClient | null = null;

function adminClient(): SupabaseClient {
  if (cachedAdmin) return cachedAdmin;
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey  = Deno.env.get("SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    throw new Error("rate-limit: missing SUPABASE_URL or SERVICE_ROLE_KEY");
  }
  cachedAdmin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return cachedAdmin;
}

// =====================================================================
// checkRateLimit — the workhorse.
// =====================================================================

export async function checkRateLimit(
  userId: string,
  endpoint: string,
  limits: TierLimits,
): Promise<RateLimitResult> {
  const admin = adminClient();

  // Tier lookup. Missing row => free.
  const { data: sub } = await admin
    .from("subscriptions")
    .select("tier")
    .eq("user_id", userId)
    .maybeSingle();

  const isPro = sub?.tier === "pro" || sub?.tier === "pro_plus";
  const bucket = isPro ? limits.pro : limits.free;

  const now = Date.now();
  const oneMinuteAgo = new Date(now - 60_000).toISOString();
  const oneDayAgo    = new Date(now - 86_400_000).toISOString();

  // 1) Per-minute cap (always present).
  const { count: minCount } = await admin
    .from("usage_events")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("endpoint", endpoint)
    .gte("created_at", oneMinuteAgo);

  if ((minCount ?? 0) >= bucket.perMinute) {
    return {
      allowed: false,
      status: 429,
      message: "Slow down — please wait a moment and try again.",
    };
  }

  // 2) Per-day cap (always present).
  const { count: dayCount } = await admin
    .from("usage_events")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("endpoint", endpoint)
    .gte("created_at", oneDayAgo);

  if ((dayCount ?? 0) >= bucket.perDay) {
    return {
      allowed: false,
      status: 429,
      message: isPro
        ? "You've reached today's high-volume limit. It resets in 24 hours."
        : "You've reached today's free limit. Upgrade to Pro for unlimited.",
    };
  }

  // 3) Per-hour cap (optional — used by livekit-token).
  if (bucket.perHour !== undefined) {
    const oneHourAgo = new Date(now - 3_600_000).toISOString();
    const { count: hourCount } = await admin
      .from("usage_events")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("endpoint", endpoint)
      .gte("created_at", oneHourAgo);
    if ((hourCount ?? 0) >= bucket.perHour) {
      return {
        allowed: false,
        status: 429,
        message: isPro
          ? "You've hit this hour's session limit. Try again in a few minutes."
          : "You've reached this hour's session limit. Upgrade to Pro for more sessions.",
      };
    }
  }

  // 4) Minimum spacing (optional — used by livekit-token for 30s spacing).
  if (bucket.minSpacingSeconds !== undefined && bucket.minSpacingSeconds > 0) {
    const sinceISO = new Date(now - bucket.minSpacingSeconds * 1000).toISOString();
    const { count: recent } = await admin
      .from("usage_events")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("endpoint", endpoint)
      .gte("created_at", sinceISO);
    if ((recent ?? 0) > 0) {
      return {
        allowed: false,
        status: 429,
        message: `Please wait ${bucket.minSpacingSeconds} seconds before starting another session.`,
      };
    }
  }

  // Passed all checks — log this call. Best-effort: if the insert fails the
  // user still gets through (we already proved they were under the limit).
  await admin
    .from("usage_events")
    .insert({ user_id: userId, endpoint });

  return { allowed: true };
}

// =====================================================================
// Helper: build a Response from a denied RateLimitResult.
// =====================================================================

export function rateLimitResponse(
  result: RateLimitResult,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(
    JSON.stringify({ error: result.message ?? "Rate limit exceeded" }),
    {
      status: result.status ?? 429,
      headers: { "Content-Type": "application/json", ...extraHeaders },
    },
  );
}
