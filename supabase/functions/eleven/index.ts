// Eleven edge function — proxies ElevenLabs streaming TTS for the RowanAI iOS app.
//
// Responsibilities:
//   - Hide the ElevenLabs API key (lives in this function's secrets, never in the app)
//   - Allowlist voice_ids so a compromised client can't enumerate the entire
//     ElevenLabs voice library on the project owner's account
//   - Allowlist model_ids and cap text length so a compromised client can't
//     run up the bill with long synthesis jobs
//   - Forward to ElevenLabs and stream the audio/mpeg response back unchanged
//
// Deploy:
//   supabase functions deploy eleven
//   supabase secrets set ELEVENLABS_API_KEY=...
//
// Auth: relies on Supabase's default JWT verification — the app sends the
// publishable (anon) key as a Bearer token, same as the cyrano function.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ELEVENLABS_BASE = "https://api.elevenlabs.io/v1/text-to-speech";

// Voice IDs from RowanAI/Features/FaceToFaceSim/SimModels.swift.
// Keep in sync when avatars are added or rotated.
const ALLOWED_VOICE_IDS = new Set([
  "vDchjyOZZytffNeZXfZK", // Jordan
  "nf4MCGNSdM0hxM95ZBQR", // Maya
  "wvk9Caj0nEx4l3I9LaR6", // Alex
  "ePEc9tlhrIO7VRkiOlQN", // Sam
  "OYTbf65OHHFELVut7v2H", // Riley
  "itkUuCeluzmxnISkRimf", // Casey
]);

const ALLOWED_MODELS = new Set([
  "eleven_flash_v2_5",
  "eleven_turbo_v2_5",
]);

// Hard cap on synthesis input. Avatar lines are 1-3 sentences; 2 KB of text
// is far more than needed and keeps a malicious client from billing the
// project owner for paragraphs.
const MAX_TEXT_LENGTH = 2_000;

// Hard cap on JSON body size. Body is small ({voice_id, text, model_id,
// voice_settings}) — 50 KB is generous.
const MAX_BODY_BYTES = 50_000;

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

function isVoiceSettings(v: unknown): v is {
  stability: number;
  similarity_boost: number;
  style: number;
  use_speaker_boost?: boolean;
} {
  if (typeof v !== "object" || v === null) return false;
  const o = v as Record<string, unknown>;
  return (
    typeof o.stability === "number" &&
    typeof o.similarity_boost === "number" &&
    typeof o.style === "number" &&
    (o.use_speaker_boost === undefined || typeof o.use_speaker_boost === "boolean")
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonError(405, "Method not allowed");
  }

  const apiKey = Deno.env.get("ELEVENLABS_API_KEY");
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

  const voiceID = body.voice_id;
  if (typeof voiceID !== "string" || !ALLOWED_VOICE_IDS.has(voiceID)) {
    return jsonError(400, "voice_id not allowed");
  }

  const text = body.text;
  if (typeof text !== "string" || text.length === 0) {
    return jsonError(400, "text required");
  }
  const safeText = text.length > MAX_TEXT_LENGTH ? text.slice(0, MAX_TEXT_LENGTH) : text;

  const modelID = body.model_id;
  if (typeof modelID !== "string" || !ALLOWED_MODELS.has(modelID)) {
    return jsonError(400, "model_id not allowed");
  }

  if (!isVoiceSettings(body.voice_settings)) {
    return jsonError(400, "voice_settings invalid");
  }

  const upstreamBody = JSON.stringify({
    text: safeText,
    model_id: modelID,
    voice_settings: body.voice_settings,
  });

  const upstream = await fetch(`${ELEVENLABS_BASE}/${voiceID}/stream`, {
    method: "POST",
    headers: {
      "xi-api-key": apiKey,
      "Content-Type": "application/json",
      "Accept": "audio/mpeg",
    },
    body: upstreamBody,
  });

  // On non-200, surface the upstream JSON body verbatim so the client can
  // log the error preview (401/403/404/422 all return JSON).
  if (!upstream.ok) {
    const errBody = await upstream.text();
    return new Response(errBody, {
      status: upstream.status,
      headers: {
        "Content-Type": upstream.headers.get("Content-Type") ?? "application/json",
        ...corsHeaders,
      },
    });
  }

  // Stream the audio body straight through — no buffering.
  return new Response(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": upstream.headers.get("Content-Type") ?? "audio/mpeg",
      "Cache-Control": "no-store",
      ...corsHeaders,
    },
  });
});
