// Cyrano edge function — proxies Anthropic Messages API for the RowanAI iOS app.
//
// Responsibilities:
//   - Hide the Anthropic API key (lives in this function's secrets, never in the app)
//   - Allowlist the model + cap max_tokens so a compromised client can't run up the bill
//   - Forward request body to Anthropic and stream the response back unchanged
//
// Deploy:
//   supabase functions deploy cyrano
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//
// Auth: relies on Supabase's default JWT verification — the app's publishable (anon)
// key is a valid JWT, so no extra auth code is needed here. If you ever want to gate
// per-user, switch to a signed-in user JWT on the client and read `user_id` from
// the verified JWT context.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

const ALLOWED_MODELS = new Set([
  "claude-sonnet-4-6",
  "claude-opus-4-7",
  "claude-haiku-4-5-20251001",
]);

const MAX_TOKENS_CAP = 2000;
// 2.5 MB — enough room for a 1 MB JPEG re-encoded as base64 (~1.4 MB) plus
// system + user text. Image content blocks pass through untouched so the
// upstream vision API receives them verbatim.
const MAX_BODY_BYTES = 2_500_000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonError(405, "Method not allowed");
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return jsonError(500, "Server not configured");
  }

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) {
    return jsonError(413, "Request body too large");
  }

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(raw);
  } catch {
    return jsonError(400, "Invalid JSON");
  }

  const model = body.model;
  if (typeof model !== "string" || !ALLOWED_MODELS.has(model)) {
    return jsonError(400, "Model not allowed");
  }

  const maxTokens = body.max_tokens;
  if (typeof maxTokens !== "number" || maxTokens <= 0) {
    return jsonError(400, "max_tokens required");
  }
  body.max_tokens = Math.min(maxTokens, MAX_TOKENS_CAP);

  const upstream = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify(body),
  });

  const respBody = await upstream.text();
  return new Response(respBody, {
    status: upstream.status,
    headers: {
      "Content-Type": upstream.headers.get("Content-Type") ?? "application/json",
      ...corsHeaders,
    },
  });
});
