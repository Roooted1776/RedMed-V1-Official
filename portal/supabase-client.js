// Single Supabase client for the portal. db.schema pins every PostgREST call
// (the SDK's .from()) to redmed_owner, the same header effect as the iOS
// client's per-request Accept-Profile/Content-Profile: redmed_owner.
// .auth.* calls are unaffected by db.schema — they always hit /auth/v1/*,
// exactly like OwnerSupabaseClient's sendEmailCode/verifyEmailCode.
//
// Imported from a locally vendored bundle, not a CDN: the account CSP is
// script-src 'self' (meta tag in index.html, and portal/nginx.conf), so
// a cross-origin ESM import would be blocked outright. vendor/supabase-js.js
// is @supabase/supabase-js@2.45.4 bundled with esbuild (--bundle --format=esm,
// zero remaining external imports) — regenerate it the same way to update.
import { createClient } from "./vendor/supabase-js.js";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "./supabase-config.js";

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  db: { schema: "redmed_owner" },
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false,
  },
});
