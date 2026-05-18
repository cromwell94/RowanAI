// set-tier — iOS pushes its StoreKit-derived subscription tier here so the
// shared rate-limit helper (cyrano / eleven / livekit-token) can apply the
// right per-tier limits.
//
// Called from StoreManager.checkEntitlements() on every entitlement change
// (purchase, restore, transaction-listener update, cold-launch entitlement
// scan). The client fires the call as `Task { try? await ... }` so failures
// never block the UI — the server-side rate limit and the upsert idempotency
// make repeated calls safe.
//
// Security model:
//   - verify_jwt = true (set in supabase/config.toml). Supabase rejects
//     callers without a valid project JWT before our code runs.
//   - We additionally require role == "authenticated" — the anon publishable
//     key has role == "anon" and is rejected.
//   - The user_id we write is the verified JWT sub; the body's tier value
//     is the only thing the client controls. A caller cannot bump someone
//     else's tier.
//   - 10/min rate limit per user prevents accidental write storms from
//     buggy app loops.
//
// v1.0 caveat: this is the iOS-side path only — accurate while the app is
// running. The robust production path (v1.0.1) is App Store Server
// Notifications V2 → an Apple-signed webhook that updates this same table
// without needing the app to be open. See memory: v101-storekit-tier-webhook.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { checkRateLimit, decodeJWTPayload, rateLimitResponse } from "../_shared/rate-limit.ts";

// Currently accepts only "free" / "pro". Pro+ users are bucketed as "pro" for
// rate-limiting purposes (the helper treats both the same), and the only
// Pro+-exclusive feature — Cyrano Live — is feature-flagged off for v1.0
// (RowanAI/Core/FeatureFlags.swift). Add "pro_plus" here if/when that flag
// flips on and Pro+ gets distinct server-enforced behaviour.
const ALLOWED_TIERS = new Set(["free", "pro"]);

const securityHeaders = {
  "Content-Type": "application/json",
  "X-Content-Type-Options": "nosniff",
};

function jsonError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: securityHeaders,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204 });
  if (req.method !== "POST") return jsonError(405, "Method not allowed");

  const claims = decodeJWTPayload(req.headers.get("Authorization"));
  if (!claims || claims.role !== "authenticated"
      || typeof claims.sub !== "string" || !claims.sub) {
    return jsonError(401, "Authenticated user required");
  }
  const userId = claims.sub;

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonError(400, "Invalid JSON");
  }

  const tier = body.tier;
  if (typeof tier !== "string" || !ALLOWED_TIERS.has(tier)) {
    return jsonError(400, "tier must be 'free' or 'pro'");
  }

  // Rate limit. 10/min covers fast app-launch loops and dev rebuilds without
  // letting a buggy client write-storm us. perDay is set high (effectively
  // capped by perMinute) — set-tier is called on every entitlement change,
  // not metered like AI calls.
  const rl = await checkRateLimit(userId, "set-tier", {
    free: { perMinute: 10, perDay: 1000 },
    pro:  { perMinute: 10, perDay: 1000 },
  });
  if (!rl.allowed) return rateLimitResponse(rl, securityHeaders);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey  = Deno.env.get("SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return jsonError(500, "Server not configured");
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { error } = await admin
    .from("subscriptions")
    .upsert(
      { user_id: userId, tier, updated_at: new Date().toISOString() },
      { onConflict: "user_id" },
    );

  if (error) {
    return jsonError(500, error.message);
  }

  return new Response(JSON.stringify({ ok: true, tier }), {
    status: 200,
    headers: securityHeaders,
  });
});
