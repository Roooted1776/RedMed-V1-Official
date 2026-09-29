// Read-only band_writes lookup — mirrors ProfileCloudSync's
// lastVerifiedBandWriteAt. The portal never writes to this table: only the
// iPhone app's verified NFC write does that.
import { supabase } from "./supabase-client.js";

/** Most recent verified band write for this user, or null if none. */
export async function getLastVerifiedWrite(userId) {
  const { data, error } = await supabase
    .from("band_writes")
    .select("written_at")
    .eq("user_id", userId)
    .order("written_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data?.written_at ?? null;
}
