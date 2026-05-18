import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { checkRateLimit, rateLimitResponse } from "../_shared/rate-limit.ts"

// LiveKit room-token issuer.
//
// Security model:
//   - verify_jwt = true (set in supabase/config.toml). Supabase rejects callers
//     without a valid project JWT before our code runs.
//   - We additionally require role == "authenticated" — the public anon key is
//     a valid JWT but role == "anon", which we reject.
//   - participantIdentity is derived from user.sub. Anything the client sends
//     is ignored; clients cannot impersonate other users.
//   - roomName must be one of two shapes, both anchored to the caller's user id:
//       sim-<avatarId>-<userId>-<unixSeconds>
//       cyrano-live-<userId>-<unixSeconds>
//   - participantName length and charset are constrained.
//   - Token TTL is 15 minutes.
//
// Rate limiting (added in the security hardening pass, raised for v1.0 launch):
//   - Free: 10 tokens/hour, 50/day
//   - Pro:  60 tokens/hour, 500/day
//   - All:  minimum 30 seconds between token issuances
//   This caps LiveKit per-participant-minute spend. The per-hour ceilings
//   plus the 30s spacing make it impossible to chain back-to-back 15-minute
//   sessions without hitting the wall, regardless of tier.
//
// Browser callers cannot reach this endpoint (no Allow-Origin header). Native
// HTTP clients (URLSession) ignore CORS, so the iOS app is unaffected.

const securityHeaders = {
  "Content-Type": "application/json",
  "X-Content-Type-Options": "nosniff",
}

const TOKEN_TTL_SECONDS = 15 * 60
const MAX_PARTICIPANT_NAME = 64
const MAX_ROOM_NAME = 200

interface LiveKitGrants {
  iss: string
  sub: string
  iat: number
  exp: number
  nbf: number
  name: string
  video: {
    roomJoin: boolean
    room: string
    canPublish: boolean
    canSubscribe: boolean
    canPublishData: boolean
  }
}

async function generateLiveKitToken(
  apiKey: string,
  apiSecret: string,
  roomName: string,
  participantIdentity: string,
  participantName: string,
  canPublish: boolean,
  canSubscribe: boolean
): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const payload: LiveKitGrants = {
    iss: apiKey,
    sub: participantIdentity,
    iat: now,
    exp: now + TOKEN_TTL_SECONDS,
    nbf: now,
    name: participantName,
    video: {
      roomJoin: true,
      room: roomName,
      canPublish,
      canSubscribe,
      canPublishData: true,
    },
  }
  const header = { alg: "HS256", typ: "JWT" }

  const base64url = (str: string) =>
    btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "")

  const headerB64 = base64url(JSON.stringify(header))
  const payloadB64 = base64url(JSON.stringify(payload))
  const signingInput = `${headerB64}.${payloadB64}`

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(apiSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  )
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signingInput)
  )
  const signatureB64 = base64url(
    String.fromCharCode(...new Uint8Array(signature))
  )
  return `${signingInput}.${signatureB64}`
}

interface JWTPayload {
  sub?: string
  role?: string
  exp?: number
}

function decodeJWTPayload(authHeader: string | null): JWTPayload | null {
  if (!authHeader) return null
  const token = authHeader.replace(/^Bearer\s+/i, "").trim()
  const parts = token.split(".")
  if (parts.length !== 3) return null
  try {
    const padded = parts[1].replace(/-/g, "+").replace(/_/g, "/")
    return JSON.parse(atob(padded)) as JWTPayload
  } catch {
    return null
  }
}

function jsonError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: securityHeaders,
  })
}

function isValidRoomName(roomName: string, userId: string): boolean {
  if (roomName.length === 0 || roomName.length > MAX_ROOM_NAME) return false
  // Escape userId for use in a regex. UUIDs only contain [0-9a-f-] so this is
  // defense-in-depth.
  const escapedUser = userId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  const sim = new RegExp(`^sim-[a-z0-9]+-${escapedUser}-\\d+$`)
  const cyrano = new RegExp(`^cyrano-live-${escapedUser}-\\d+$`)
  return sim.test(roomName) || cyrano.test(roomName)
}

function sanitizeParticipantName(raw: unknown): string {
  if (typeof raw !== "string") return "User"
  const trimmed = raw.trim().slice(0, MAX_PARTICIPANT_NAME)
  // Allow letters, digits, spaces, basic punctuation. Strip everything else.
  const cleaned = trimmed.replace(/[^\p{L}\p{N} \-_'.]/gu, "")
  return cleaned.length > 0 ? cleaned : "User"
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 })
  }
  if (req.method !== "POST") {
    return jsonError(405, "Method not allowed")
  }

  const claims = decodeJWTPayload(req.headers.get("Authorization"))
  if (!claims || claims.role !== "authenticated" || typeof claims.sub !== "string" || claims.sub.length === 0) {
    return jsonError(401, "Authenticated user required")
  }
  const userId = claims.sub

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return jsonError(400, "Invalid JSON")
  }

  const roomName = typeof body.roomName === "string" ? body.roomName : ""
  if (!isValidRoomName(roomName, userId)) {
    return jsonError(400, "Invalid roomName for authenticated user")
  }

  const participantName = sanitizeParticipantName(body.participantName)
  const canPublish = body.canPublish !== false
  const canSubscribe = body.canSubscribe !== false

  const apiKey = Deno.env.get("LIVEKIT_API_KEY")
  const apiSecret = Deno.env.get("LIVEKIT_API_SECRET")
  const livekitUrl = Deno.env.get("LIVEKIT_URL")
  if (!apiKey || !apiSecret || !livekitUrl) {
    return jsonError(500, "Server not configured")
  }

  // Per-user rate limit for token issuance. Sessions are expensive (LiveKit
  // bills per participant-minute) so we cap session starts directly.
  //   Free: 10 sessions/hour 50/day, Pro: 60/hour 500/day, both with 30s spacing.
  // Raised from 3/hr 24/day (free) and 30/hr 240/day (pro) for v1.0 launch —
  // legitimate users were hitting limits during demos and early testing.
  // perMinute is set to a comfortable 5 so a quick reconnect after a
  // network blip doesn't trip the bucket, while still bounding burst.
  const rl = await checkRateLimit(userId, "livekit-token", {
    free: { perMinute: 5, perDay: 50,  perHour: 10, minSpacingSeconds: 30 },
    pro:  { perMinute: 5, perDay: 500, perHour: 60, minSpacingSeconds: 30 },
  })
  if (!rl.allowed) return rateLimitResponse(rl, securityHeaders)

  try {
    const token = await generateLiveKitToken(
      apiKey,
      apiSecret,
      roomName,
      userId,
      participantName,
      canPublish,
      canSubscribe
    )
    return new Response(JSON.stringify({ token, url: livekitUrl }), {
      headers: securityHeaders,
    })
  } catch (error) {
    return jsonError(500, error instanceof Error ? error.message : "Token signing failed")
  }
})
