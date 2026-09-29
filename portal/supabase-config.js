// Public Supabase project config for the RedMed account portal.
//
// This key is the publishable (anon) key, not a secret: it is designed to be
// embedded in public clients and is inert without row-level security, which
// is already enforced on redmed_owner.profiles / redmed_owner.band_writes
// (see supabase/migrations/*redmed_owner*.sql). It is committed on purpose —
// unlike owner/Config/Supabase.xcconfig (gitignored on the iOS side to keep
// per-build config out of a compiled App Store binary), this portal has one
// fixed production target and nothing to gate per build.
//
// Never put a service_role key here or anywhere under portal/.
export const SUPABASE_URL = "https://mohxobgyjkcmkqxijgeg.supabase.co";
export const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_VsdZTu51pz2a0VAnNdsJTQ_ZuFD7g7x";
