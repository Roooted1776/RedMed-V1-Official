#!/usr/bin/env bash
# Flip NFC band hardware on or off in lockstep, then prove it with the contract.
#
#   scripts/nfc-hardware.sh on    # needs a paid Apple Developer team (see docs/NFC-RESTORE.md)
#   scripts/nfc-hardware.sh off   # park again
#   scripts/nfc-hardware.sh status
#
# Touches exactly what test-nfc-hardware.mjs holds in lockstep:
#   AppConfig.nfcHardwareEnabled + associatedDomainsEnabled
#   RedMed.entitlements: NFC Tag Reading (NDEF) + applinks:<write host>
#   Info.plist: NFCReaderUsageDescription
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/owner/RedMed"
CFG="$APP/AppConfig.swift"
ENT="$APP/RedMed.entitlements"
PLIST="$APP/Info.plist"
HOST="redmed.live"
USAGE="RedMed writes your medical card to your RedMed band and reads it back to check the write. It only reads or writes when you tap Write The Band."

mode="${1:-status}"

case "$mode" in
  status)
    grep -E 'static let (nfcHardwareEnabled|associatedDomainsEnabled) =' "$CFG" | sed 's/^ *//'
    grep -q 'com.apple.developer.nfc.readersession' "$ENT" && echo "entitlement: NFC on" || echo "entitlement: NFC off"
    grep -q "applinks:$HOST" "$ENT" && echo "entitlement: applinks on" || echo "entitlement: applinks off"
    grep -q NFCReaderUsageDescription "$PLIST" && echo "Info.plist: usage on" || echo "Info.plist: usage off"
    exit 0
    ;;
  on|off) ;;
  *) echo "usage: $0 on|off|status" >&2; exit 2 ;;
esac

python3 - "$mode" "$CFG" "$ENT" "$PLIST" "$HOST" "$USAGE" <<'PY'
import plistlib, re, sys
mode, cfg, ent, plist, host, usage = sys.argv[1:]
on = mode == "on"

src = open(cfg).read()
for flag in ("nfcHardwareEnabled", "associatedDomainsEnabled"):
    src, n = re.subn(rf"static let {flag} = (true|false)", f"static let {flag} = {'true' if on else 'false'}", src)
    assert n == 1, f"{flag} not found exactly once"
open(cfg, "w").write(src)

with open(ent, "rb") as f:
    e = plistlib.load(f)
if on:
    e["com.apple.developer.nfc.readersession.formats"] = ["NDEF"]
    e["com.apple.developer.associated-domains"] = [f"applinks:{host}"]
else:
    e.pop("com.apple.developer.nfc.readersession.formats", None)
    e.pop("com.apple.developer.associated-domains", None)
with open(ent, "wb") as f:
    plistlib.dump(e, f, sort_keys=True)

with open(plist, "rb") as f:
    p = plistlib.load(f)
if on:
    p["NFCReaderUsageDescription"] = usage
else:
    p.pop("NFCReaderUsageDescription", None)
with open(plist, "wb") as f:
    plistlib.dump(p, f, sort_keys=True)
PY

node "$ROOT/scripts/test-nfc-hardware.mjs" | tail -2
"$0" status
