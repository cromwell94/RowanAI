import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Deletes the calling user's Supabase auth account.
//
// Security model:
//   - verify_jwt = true (set in supabase/config.toml). Supabase rejects callers
//     without a valid project JWT before our code runs.
//   - We additionally require role == "authenticated" — the public anon key is
//     a valid JWT but role == "anon", which we reject.
//   - The user id to delete is derived from the verified JWT (user.sub).
//     Anything the client sends in the body is ignored, so a caller cannot
//     delete a different user.
//   - Admin delete uses SERVICE_ROLE_KEY (renamed from SUPABASE_SERVICE_ROLE_KEY
//     because Supabase rejects secrets prefixed with SUPABASE_). Only ever read
//     server-side here.
//
// Browser callers cannot reach this endpoint (no Allow-Origin header). Native
// HTTP clients (URLSession) ignore CORS, so the iOS app is unaffected.

const securityHeaders = {
  "Content-Type": "application/json",
  "X-Content-Type-Options": "nosniff",
}

interface JWTPayload {
  sub?: string
  role?: string
  exp?: number
}

function decodeJWTPayload(token: string): JWTPayload | null {
  try {
    const parts = token.split(".")
    if (parts.length !== 3) return null
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/")
    const padded = payload + "=".repeat((4 - payload.length % 4) % 4)
    return JSON.parse(atob(padded))
  } catch {
    return null
  }
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: securityHeaders,
    })
  }

  const authHeader = req.headers.get("Authorization") ?? ""
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : ""
  if (!token) {
    return new Response(JSON.stringify({ error: "Missing bearer token" }), {
      status: 401,
      headers: securityHeaders,
    })
  }

  const claims = decodeJWTPayload(token)
  if (!claims || !claims.sub) {
    return new Response(JSON.stringify({ error: "Invalid token" }), {
      status: 401,
      headers: securityHeaders,
    })
  }
  if (claims.role !== "authenticated") {
    return new Response(JSON.stringify({ error: "Authenticated session required" }), {
      status: 403,
      headers: securityHeaders,
    })
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL") ?? ""
  const serviceKey  = Deno.env.get("SERVICE_ROLE_KEY") ?? ""
  if (!supabaseURL || !serviceKey) {
    return new Response(JSON.stringify({ error: "Server not configured" }), {
      status: 500,
      headers: securityHeaders,
    })
  }

  const admin = createClient(supabaseURL, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { error } = await admin.auth.admin.deleteUser(claims.sub)
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: securityHeaders,
    })
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: securityHeaders,
  })
})
