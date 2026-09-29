// Email one-time-code auth, mirroring owner/RedMed/OwnerSupabaseClient.swift's
// sendEmailCode/verifyEmailCode (/auth/v1/otp then /auth/v1/verify, type
// "email"). No password anywhere, matching the iOS app's design.
import { supabase } from "./supabase-client.js";

/** Sends a one-time code to `email`. Throws with a message on failure. */
export async function sendCode(email) {
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: true },
  });
  if (error) throw new Error(error.message);
}

/** Verifies the 6-digit code and establishes a session. */
export async function verifyCode(email, token) {
  const { data, error } = await supabase.auth.verifyOtp({
    email,
    token,
    type: "email",
  });
  if (error) throw new Error(error.message);
  return data.session;
}

/** Current session, or null if signed out. */
export async function getSession() {
  const { data } = await supabase.auth.getSession();
  return data.session;
}

/** Local sign-out only (this browser). Matches iOS "Sign Out". */
export async function signOut() {
  await supabase.auth.signOut({ scope: "local" });
}

/** Revokes every session on the account. Matches iOS "Sign Out All Devices". */
export async function signOutAllDevices() {
  const { error } = await supabase.auth.signOut({ scope: "global" });
  if (error) throw new Error(error.message);
}

/** Fires `callback(session | null)` on sign-in, sign-out, and token refresh. */
export function onAuthChange(callback) {
  supabase.auth.onAuthStateChange((_event, session) => callback(session));
}

/**
 * Deletes the sign-in itself (redmed_owner.delete_my_account). The account
 * copy and band-write log cascade on the server. Drops the local session
 * only after the server confirms — matches OwnerSupabaseClient.deleteAccount().
 */
export async function deleteAccount() {
  const { error } = await supabase.rpc("delete_my_account");
  if (error) throw new Error(error.message);
  await supabase.auth.signOut({ scope: "local" });
}
