import { sendCode, verifyCode, getSession, signOut, signOutAllDevices, deleteAccount, onAuthChange } from "./auth.js";
import { getProfile, saveProfile } from "./profile.js";
import { getLastVerifiedWrite } from "./band.js";

const $ = (id) => document.getElementById(id);

const views = {
  email: $("view-email"),
  code: $("view-code"),
  profile: $("view-profile"),
};
function show(name) {
  for (const key of Object.keys(views)) views[key].hidden = key !== name;
}

function setNote(el, text, isError = false) {
  el.textContent = text ?? "";
  el.classList.toggle("error", isError);
}

let pendingEmail = "";
let resendAvailableAt = 0;
let resendTimer = null;

function tickResend() {
  const secondsLeft = Math.max(0, Math.ceil((resendAvailableAt - Date.now()) / 1000));
  const btn = $("resend-code");
  if (secondsLeft > 0) {
    btn.disabled = true;
    btn.textContent = `Resend in ${secondsLeft}s`;
  } else {
    btn.disabled = false;
    btn.textContent = "Resend";
    clearInterval(resendTimer);
    resendTimer = null;
  }
}

function armResendCooldown() {
  resendAvailableAt = Date.now() + 60_000;
  tickResend();
  if (resendTimer) clearInterval(resendTimer);
  resendTimer = setInterval(tickResend, 1000);
}

// --- Email step ---
async function requestCode(email, note) {
  setNote(note, "");
  try {
    await sendCode(email);
    pendingEmail = email;
    $("code-target").textContent = email;
    setNote($("code-note"), `We sent a code to ${email}.`);
    armResendCooldown();
    show("code");
    $("code-input").focus();
  } catch (err) {
    setNote(note, err.message, true);
  }
}

$("email-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  await requestCode($("email-input").value.trim(), $("email-note"));
});

// --- Code step ---
$("code-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const token = $("code-input").value.trim();
  const note = $("code-note");
  try {
    await verifyCode(pendingEmail, token);
    // onAuthChange below loads the profile view once the session lands.
  } catch (err) {
    setNote(note, err.message, true);
  }
});

$("resend-code").addEventListener("click", async () => {
  if ($("resend-code").disabled) return;
  await requestCode(pendingEmail, $("code-note"));
});

$("use-different-email").addEventListener("click", () => {
  $("code-input").value = "";
  if (resendTimer) clearInterval(resendTimer);
  show("email");
  $("email-input").focus();
});

// --- Profile step ---
let currentUserId = null;

function linesToList(text) {
  return text
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
}
function listToLines(list) {
  return (list ?? []).join("\n");
}

function readContactsFromForm() {
  const rows = document.querySelectorAll("#contacts-list .contact-row");
  return Array.from(rows)
    .map((row) => ({
      name: row.querySelector(".contact-name").value.trim(),
      relationship: row.querySelector(".contact-relationship").value.trim(),
      phone: row.querySelector(".contact-phone").value.trim(),
    }))
    .filter((c) => c.name || c.phone);
}

function addContactRow(contact = { name: "", relationship: "", phone: "" }) {
  const row = document.createElement("div");
  row.className = "contact-row";
  row.innerHTML = `
    <input class="contact-name" placeholder="Name" value="${escapeAttr(contact.name)}">
    <input class="contact-relationship" placeholder="Relationship" value="${escapeAttr(contact.relationship)}">
    <input class="contact-phone" placeholder="Phone" type="tel" value="${escapeAttr(contact.phone)}">
    <button type="button" class="remove-contact" aria-label="Remove contact">✕</button>
  `;
  row.querySelector(".remove-contact").addEventListener("click", () => row.remove());
  $("contacts-list").appendChild(row);
}

function escapeAttr(s) {
  return String(s ?? "").replace(/&/g, "&amp;").replace(/"/g, "&quot;");
}

$("add-contact").addEventListener("click", () => addContactRow());

function fillForm(profile) {
  $("f-name").value = profile.name ?? "";
  $("f-birth-date").value = profile.birth_date ?? "";
  $("f-blood-type").value = profile.blood_type ?? "";
  $("f-allergies").value = listToLines(profile.allergies);
  $("f-medications").value = listToLines(profile.medications);
  $("f-conditions").value = listToLines(profile.conditions);
  $("f-notes").value = profile.notes ?? "";
  $("f-organ-donor").checked = !!profile.is_organ_donor;
  $("f-pregnant").checked = !!profile.is_pregnant;
  $("f-deaf-vision").checked = !!profile.is_deaf_or_vision_impaired;
  $("contacts-list").innerHTML = "";
  (profile.contacts ?? []).forEach(addContactRow);
  $("last-updated").textContent = profile.last_updated
    ? `Last updated ${profile.last_updated}`
    : "Not saved yet";
}

function setPill(label, kind) {
  const pill = $("status-pill");
  pill.textContent = label;
  pill.classList.remove("ok", "warn");
  if (kind) pill.classList.add(kind);
}

function relativeTime(iso) {
  if (!iso) return null;
  const date = new Date(iso);
  const seconds = Math.round((Date.now() - date.getTime()) / 1000);
  if (seconds < 60) return "Just now";
  const units = [
    ["year", 31536000], ["month", 2592000], ["day", 86400],
    ["hour", 3600], ["minute", 60],
  ];
  for (const [name, secs] of units) {
    const n = Math.floor(seconds / secs);
    if (n >= 1) return `${n} ${name}${n > 1 ? "s" : ""} ago`;
  }
  return "Just now";
}

async function loadProfileView(session) {
  currentUserId = session.user.id;
  $("signed-in-email").textContent = session.user.email ?? "";
  setPill("Syncing…");
  try {
    const profile = await getProfile(currentUserId);
    fillForm(profile);
    setPill("Up to date", "ok");
    $("last-synced").textContent = profile.updated_at
      ? `Last synced ${relativeTime(profile.updated_at)}`
      : "Not synced yet";
  } catch (err) {
    setPill("Needs retry", "warn");
    $("last-synced").textContent = err.message;
  }
  try {
    const writtenAt = await getLastVerifiedWrite(currentUserId);
    $("band-status").textContent = writtenAt
      ? `Last verified write ${relativeTime(writtenAt)}`
      : "Not on this iPhone yet";
  } catch (err) {
    $("band-status").textContent = "Couldn't check band status.";
  }
  show("profile");
}

$("profile-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const note = $("profile-note");
  setNote(note, "Saving…");
  try {
    const saved = await saveProfile(currentUserId, {
      name: $("f-name").value.trim(),
      birth_date: $("f-birth-date").value.trim(),
      blood_type: $("f-blood-type").value.trim(),
      allergies: linesToList($("f-allergies").value),
      medications: linesToList($("f-medications").value),
      conditions: linesToList($("f-conditions").value),
      notes: $("f-notes").value.trim(),
      is_organ_donor: $("f-organ-donor").checked,
      is_pregnant: $("f-pregnant").checked,
      is_deaf_or_vision_impaired: $("f-deaf-vision").checked,
      contacts: readContactsFromForm(),
    });
    $("last-updated").textContent = `Last updated ${saved.last_updated}`;
    setNote(note, "Saved.");
    setPill("Up to date", "ok");
    $("last-synced").textContent = "Last synced just now";
  } catch (err) {
    setNote(note, err.message, true);
    setPill("Needs retry", "warn");
  }
});

$("sign-out").addEventListener("click", async () => {
  await signOut();
});

$("sign-out-all").addEventListener("click", async () => {
  if (!confirm("Sign out on every device signed into this account? RedMed and your band are unchanged.")) return;
  try {
    await signOutAllDevices();
  } catch (err) {
    alert(err.message);
  }
});

$("delete-account").addEventListener("click", async () => {
  const ok = confirm(
    "Delete this account?\n\nDeletes your sign-in and the account copy of your card. This can't be undone. " +
    "Your iPhone app and your band are not changed."
  );
  if (!ok) return;
  try {
    await deleteAccount();
    // onAuthChange fires session=null and returns to the email step.
  } catch (err) {
    alert(err.message);
  }
});

// --- Boot ---
onAuthChange((session) => {
  if (session) {
    loadProfileView(session);
  } else {
    pendingEmail = "";
    show("email");
  }
});

(async () => {
  const session = await getSession();
  if (session) {
    await loadProfileView(session);
  } else {
    show("email");
  }
})();
