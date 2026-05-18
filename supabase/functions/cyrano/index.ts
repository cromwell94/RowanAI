// Cyrano edge function — proxies Anthropic Messages API for the RowanAI iOS app.
//
// Responsibilities:
//   - Hide the Anthropic API key (lives in this function's secrets, never in the app)
//   - Require an AUTHENTICATED user JWT (anon JWT rejected) so we can rate-limit
//     per user.sub — the wallet-side defence against runaway billing
//   - Allowlist the model + cap max_tokens so a compromised client can't run up the bill
//   - Apply a per-user rate limit (see _shared/rate-limit.ts)
//   - Tighten the body cap for text-only requests (50 KB) while still allowing
//     base64 image payloads (2.5 MB)
//   - Pre-filter obvious prompt-injection phrases — short-circuit before the
//     expensive upstream call so attackers can't burn tokens on jailbreak attempts
//   - Forward request body to Anthropic and stream the response back unchanged
//
// Deploy:
//   supabase functions deploy cyrano
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase secrets set SERVICE_ROLE_KEY=eyJ...   (required by _shared/rate-limit.ts)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { checkRateLimit, decodeJWTPayload, rateLimitResponse } from "../_shared/rate-limit.ts";

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

const ALLOWED_MODELS = new Set([
  "claude-sonnet-4-6",
  "claude-opus-4-7",
  "claude-haiku-4-5-20251001",
]);

// v1.0: Cyrano is now a 5-mode communication toolkit. The mode is sent in
// the request body and used to bucket usage_events per mode so each gets
// its own daily limit (5/day free, 100/day pro). Unknown / missing modes
// default to "reply" so older iOS builds that haven't been updated still
// route through the rate-limit helper safely.
const ALLOWED_MODES = new Set([
  "reply",
  "opener",
  "translate",
  "decode",
  "pulse",
]);

// Anthropic Messages API body whitelist — only these keys are forwarded
// upstream. Internal fields like `mode` (used for our per-mode rate-limit
// bucketing) must be stripped here or Anthropic returns
// `HTTP 400 — mode: Extra inputs are not permitted` and the whole call fails.
// Source of truth: https://docs.anthropic.com/en/api/messages.
// `anthropic-version` is sent as a header, not a body field, so it's not in
// this set.
const ANTHROPIC_BODY_FIELDS = new Set<string>([
  "model",
  "max_tokens",
  "messages",
  "system",
  "temperature",
  "top_p",
  "stop_sequences",
  "stream",
  "tools",
  "tool_choice",
  "metadata",
]);

function pickAnthropicFields(
  input: Record<string, unknown>,
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const k of Object.keys(input)) {
    if (ANTHROPIC_BODY_FIELDS.has(k)) out[k] = input[k];
  }
  return out;
}

const MAX_TOKENS_CAP = 2000;

// Body size caps. The wide cap (with image) is sized for a 1 MB JPEG re-encoded
// as base64 (~1.4 MB) plus system + user text. The narrow cap (text-only)
// keeps a malicious caller from sending 2 MB of text to Claude — at ~$3/M
// input tokens for Sonnet, 2 MB of text would cost roughly $1.50 per call
// in input tokens alone.
const MAX_BODY_BYTES_WITH_IMAGE  = 2_500_000;
const MAX_BODY_BYTES_TEXT_ONLY   = 50_000;

// Prompt-injection patterns. Matched case-insensitively with word boundaries
// to keep false-positives down (e.g. "Daniel" doesn't trigger "DAN"). On a
// hit we return 400 before calling upstream — no Anthropic spend on
// jailbreak attempts. Cyrano's system prompt has belt-and-suspenders identity
// hardening as well; this layer just spares the wallet.
//
// "DAN" is left case-sensitive on purpose: the jailbreak persona is the
// canonical capitalised "DAN", and lowercasing it would false-positive on
// the common name "Dan".
const INJECTION_PATTERNS: RegExp[] = [
  /\bignore\s+previous\b/i,
  /\bdisregard\s+previous\b/i,
  /\byou\s+are\s+now\b/i,
  /\bact\s+as\b/i,
  /\bDAN\b/,
  /\bdeveloper\s+mode\b/i,
  /\boverride\s+your\b/i,
  /\bsystem\s+prompt\b/i,
  /\bforget\s+your\b/i,
  /\bfrom\s+now\s+on\b/i,
  /\bpretend\s+you\s+are\b/i,
  /\bjailbreak\b/i,
];

// App-only endpoint: no CORS allowance. Browsers will fail; native iOS
// (URLSession) ignores CORS, so the app is unaffected.
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

// Detect whether the request body contains an image content block. We only
// need the boolean — the exact image payload is forwarded to Anthropic
// untouched. Defensive against malformed input (returns false on anything
// that isn't shaped like Anthropic's vision payload).
function hasImage(messages: unknown): boolean {
  if (!Array.isArray(messages)) return false;
  for (const m of messages) {
    if (typeof m !== "object" || m === null) continue;
    const content = (m as Record<string, unknown>).content;
    if (!Array.isArray(content)) continue;
    for (const block of content) {
      if (typeof block === "object" && block !== null
          && (block as Record<string, unknown>).type === "image") {
        return true;
      }
    }
  }
  return false;
}

// Extract every text fragment the user sent (across all user-role messages
// and all text blocks within them). Used by the injection pre-filter — we
// scan only what came from the user, never the system prompt.
function extractUserText(messages: unknown): string {
  if (!Array.isArray(messages)) return "";
  const parts: string[] = [];
  for (const m of messages) {
    if (typeof m !== "object" || m === null) continue;
    const role = (m as Record<string, unknown>).role;
    if (role !== "user") continue;
    const content = (m as Record<string, unknown>).content;
    if (typeof content === "string") {
      parts.push(content);
    } else if (Array.isArray(content)) {
      for (const block of content) {
        if (typeof block !== "object" || block === null) continue;
        const b = block as Record<string, unknown>;
        if (b.type === "text" && typeof b.text === "string") parts.push(b.text);
      }
    }
  }
  return parts.join("\n");
}

function detectInjection(text: string): RegExp | null {
  for (const pattern of INJECTION_PATTERNS) {
    if (pattern.test(text)) return pattern;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }
  if (req.method !== "POST") {
    return jsonError(405, "Method not allowed");
  }

  // Require an authenticated user JWT. The iOS app now sends the user JWT
  // obtained via SupabaseAuth.shared.currentAccessToken() instead of the
  // publishable anon key — this is what gives us a per-user `sub` to
  // rate-limit against.
  const claims = decodeJWTPayload(req.headers.get("Authorization"));
  if (!claims || claims.role !== "authenticated"
      || typeof claims.sub !== "string" || !claims.sub) {
    return jsonError(401, "Authenticated user required");
  }
  const userId = claims.sub;

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return jsonError(500, "Server not configured");
  }

  // First-pass size check — use the wide cap so we don't reject legitimate
  // image payloads. The text-only cap is enforced after we know whether the
  // parsed body contains an image.
  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES_WITH_IMAGE) {
    return jsonError(413, "Request body too large");
  }

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(raw);
  } catch {
    return jsonError(400, "Invalid JSON");
  }

  // Conditional body cap. Text-only requests must fit in 50 KB.
  const withImage = hasImage(body.messages);
  if (!withImage && raw.length > MAX_BODY_BYTES_TEXT_ONLY) {
    return jsonError(413, "Request body too large");
  }

  // Prompt-injection pre-filter. Cheap; runs before the rate-limit check
  // because we don't want a hostile caller's injection attempts to count
  // against their daily quota — those calls cost us nothing upstream.
  const userText = extractUserText(body.messages);
  if (detectInjection(userText) !== null) {
    return jsonError(400, "Cyrano can't help with that — try rephrasing your message.");
  }

  // Model + max_tokens validation.
  const model = body.model;
  if (typeof model !== "string" || !ALLOWED_MODELS.has(model)) {
    return jsonError(400, "Model not allowed");
  }
  const maxTokens = body.max_tokens;
  if (typeof maxTokens !== "number" || maxTokens <= 0) {
    return jsonError(400, "max_tokens required");
  }
  body.max_tokens = Math.min(maxTokens, MAX_TOKENS_CAP);

  // Per-user, per-mode rate limit. v1.0 buckets are:
  //   cyrano_reply / cyrano_opener / cyrano_translate / cyrano_decode / cyrano_pulse
  // Each gets 5/day free, 100/day pro. The per-minute cap is per-mode here
  // (10/min/mode); a stricter "10/min across all modes" needs a second
  // checkRateLimit call against a shared "cyrano_all" bucket and is deferred
  // to a future iteration if the per-mode cap proves too loose in practice.
  const rawMode = typeof body.mode === "string" ? body.mode : "reply";
  const mode = ALLOWED_MODES.has(rawMode) ? rawMode : "reply";
  const rl = await checkRateLimit(userId, `cyrano_${mode}`, {
    free: { perMinute: 10, perDay: 5   },
    pro:  { perMinute: 10, perDay: 100 },
  });
  if (!rl.allowed) return rateLimitResponse(rl, securityHeaders);

  // Filter body to the Anthropic-accepted whitelist. This drops our internal
  // `mode` field (and any future internal-only fields) before forwarding.
  // Run AFTER the rate-limit check above, which still needs `body.mode`.
  const anthropicBody = pickAnthropicFields(body);

  const upstream = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify(anthropicBody),
  });

  const respBody = await upstream.text();
  return new Response(respBody, {
    status: upstream.status,
    headers: {
      "Content-Type": upstream.headers.get("Content-Type") ?? "application/json",
      "X-Content-Type-Options": "nosniff",
    },
  });
});
