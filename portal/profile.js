// redmed_owner.profiles read/write, field-for-field with
// owner/RedMed/OwnerSupabaseClient.swift's OwnerProfileRecord. bracelet_linked
// is intentionally never read or written here — it's a this-device CoreNFC
// verification flag, not something a browser session should claim or touch.
import { supabase } from "./supabase-client.js";

const COLUMNS =
  "id,name,birth_date,blood_type,allergies,medications,conditions,contacts,is_organ_donor,is_pregnant,is_deaf_or_vision_impaired,last_updated,notes,updated_at";

/** The signed-in user's profile row, or a blank default if none exists yet. */
export async function getProfile(userId) {
  const { data, error } = await supabase
    .from("profiles")
    .select(COLUMNS)
    .eq("id", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data ?? blankProfile(userId);
}

function blankProfile(userId) {
  return {
    id: userId,
    name: "",
    birth_date: "",
    blood_type: "",
    allergies: [],
    medications: [],
    conditions: [],
    contacts: [],
    is_organ_donor: false,
    is_pregnant: false,
    is_deaf_or_vision_impaired: false,
    last_updated: "",
    notes: "",
  };
}

/** Upserts the full row. Stamps last_updated to today, like the iOS Save path. */
export async function saveProfile(userId, fields) {
  const row = {
    id: userId,
    name: fields.name,
    birth_date: fields.birth_date,
    blood_type: fields.blood_type,
    allergies: fields.allergies,
    medications: fields.medications,
    conditions: fields.conditions,
    contacts: fields.contacts,
    is_organ_donor: fields.is_organ_donor,
    is_pregnant: fields.is_pregnant,
    is_deaf_or_vision_impaired: fields.is_deaf_or_vision_impaired,
    last_updated: new Date().toLocaleDateString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
    }),
    notes: fields.notes,
  };
  const { data, error } = await supabase
    .from("profiles")
    .upsert(row, { onConflict: "id" })
    .select(COLUMNS)
    .single();
  if (error) throw new Error(error.message);
  return data;
}
