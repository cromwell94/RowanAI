import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// LiveKit JWT token generation using Web Crypto API (Deno-compatible)
async function generateLiveKitToken(
  apiKey: string,
  apiSecret: string,
  roomName: string,
  participantIdentity: string,
  participantName: string,
  canPublish: boolean = true,
  canSubscribe: boolean = true
): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const exp = now + 3600 // 1 hour

  const header = { alg: "HS256", typ: "JWT" }
  const payload = {
    iss: apiKey,
    sub: participantIdentity,
    iat: now,
    exp: exp,
    nbf: now,
    name: participantName,
    video: {
      roomJoin: true,
      room: roomName,
      canPublish: canPublish,
      canSubscribe: canSubscribe,
      canPublishData: true,
    },
  }

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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const apiKey = Deno.env.get("LIVEKIT_API_KEY")!
    const apiSecret = Deno.env.get("LIVEKIT_API_SECRET")!
    const livekitUrl = Deno.env.get("LIVEKIT_URL")!

    const body = await req.json()
    const {
      roomName,
      participantIdentity,
      participantName = "User",
      canPublish = true,
      canSubscribe = true,
    } = body

    if (!roomName || !participantIdentity) {
      return new Response(
        JSON.stringify({ error: "roomName and participantIdentity required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const token = await generateLiveKitToken(
      apiKey,
      apiSecret,
      roomName,
      participantIdentity,
      participantName,
      canPublish,
      canSubscribe
    )

    return new Response(
      JSON.stringify({ token, url: livekitUrl }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
