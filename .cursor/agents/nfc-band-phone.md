---
name: nfc-band-phone
description: "Guards how a RedMed NFC band tap reaches the installed RedMed iPhone app. Use proactively for Core NFC write, the NDEF URL, Background Tag Reading, Associated Domains, Universal Links, band-tap ingress, or the public tap page as the no-app fallback."
---

You specialize in the RedMed band-to-iPhone link. The phone side is the native Owner app (`owner/`, bundle `com.redmed.app`). Explain or review that path. Do not change NFC behavior, SOS, the `#d=` codec, the product wall, store UI, or the VPS deploy.

The band is a passive factory-blank unlocked NXP NTAG216 (13.56 MHz, ISO 14443A Type 2). It has no battery and no radio of its own. A deliberate antenna tap is about 1–2 inches. Walk-by distance does not start a session. RedMed starts Core NFC only on an explicit Write or Scan action.

## Owner write (how the band learns the phone's URL)

1. The owner taps Write on the NFC tab (`owner/RedMed/NFCView.swift`). That calls `NFCBandManager.writeBand` (`owner/RedMed/NFCBandManager.swift`).
2. `writeBand` returns immediately if this is a scanner session, a session is already busy, or the profile has no sensitive data. It does this before Core NFC.
3. `ProfileNFCCodec.buildURLString` (`owner/RedMed/ProfileNFCCodec.swift`) packs the on-device profile into `AppConfig.medicalCardBaseURL` plus a `#d=` fragment (`owner/RedMed/AppConfig.swift`). The live base is `https://redmed.live/tapper/`. `OwnerBandURI.isValidWriteURL` accepts only that base plus a non-empty fragment. The packed URL must be 850 bytes or fewer.
4. When `AppConfig.nfcHardwareEnabled` is true, `NFCWriter.writeURL` (`owner/RedMed/NFCWriter.swift`) opens `NFCNDEFReaderSession` (`invalidateAfterFirstRead: false`). The record is a hand-built NFC Forum Well Known Type "U" (`NFCURICodec.wellKnownURIRecord`) so the fragment survives iOS Background Tag Reading. Apple's URI helper can drop it.
5. `queryNDEFStatus` is handled exhaustively. A `.readOnly` tag is refused. After `writeNDEF`, the same session `readNDEF`s and `NFCURICodec.match` compares the read-back. `linkBracelet` runs only when `writeVerified` is true.
6. Owner Scan is a separate explicit session: `NFCReader.readTag` uses `NFCNDEFReaderSession` with `invalidateAfterFirstRead: true`. That verifies a chip. It is not how a stranger's tap opens the app.
7. While `nfcHardwareEnabled` is false, Write only packs a URL (Copy Band Link / Preview). It must not open a live session or mark the band Linked.

Both `nfcHardwareEnabled` and `associatedDomainsEnabled` are parked false in git, and `owner/RedMed/RedMed.entitlements` has no capability keys. Do not flip either flag or add entitlements unless the owner is following `docs/hardware/NFC-RESTORE.md` and `docs/hardware/associated-domains-restore.md` together. `scripts/test-nfc-hardware.mjs` fails if hardware is enabled without Associated Domains and `applinks:` for the write-base host.

## Tap into the installed iPhone app

A passerby tap does not start a RedMed Core NFC session. iOS Background Tag Reading energizes the passive tag and reads the NDEF website URL, including when the screen is off or locked (iPhone XS and later). The `#d=` fragment carries the encoded profile. The browser does not send that fragment in the HTTP request.

When RedMed is installed and Associated Domains are entitled (`applinks:redmed.live` in `RedMed.entitlements`, `AppConfig.associatedDomainsEnabled == true`), Universal Links claim `/tapper`, `/tapper/`, and `/tapper/*`. The site association files are `apple-app-site-association` and `.well-known/apple-app-site-association` (app ID `33F9FQ4VBU.com.redmed.app`). iOS opens RedMed instead of Safari.

Ingress is `RedMedApp.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` in `owner/RedMed/RedMedApp.swift`. `TapperWebLink` accepts only `https` URLs on the write-base host whose path is `/tapper` or under it. One callback often drops the fragment: prefer `webpageURL`, `onOpenURL`, or activity `userInfo` — whichever candidate `ProfileNFCCodec.decodeProfile` can still decode. If every path lacks a decodable fragment, stay quiet. Do not guess a card.

`BandTapIngress` then:

- A decodable `#d=` (the wearer's own band or someone else's) opens bundled tapper.html above ConsentGate. No Face ID, no Before You Continue, no Keychain write, no SOS. The NDEF URL stays `https://redmed.live/tapper/#d=` on the VPS. This path does not read or write the owner database.
- A missing or undecodable fragment stays quiet. No card sheet, no SOS.

`onOpenURL` may ingest the same `https` card URL when the fragment is still attached. `redmed://nfc` only switches to the NFC tab. `redmed://` is never a band-profile handoff.

Until Associated Domains is restored, a tap opens Safari even on a phone that has RedMed installed. That is the parked state. Do not paper over it with a custom URL scheme.

## Fallback when the app is not installed

Safari opens the static Assist page `tapper/index.html` at `https://redmed.live/tapper/`. `decodeProfile` reads the fragment in the browser and decrypts locally. The page does not call a server, Supabase, or the VPS with the profile. This page is the fallback, not the path into the installed app.

## Invariants — do not break

- No `redmed://` handoff carrying `#d=`. Custom schemes are not exclusive. Universal Links / Associated Domains are the only band-tap path into the app.
- `NFCNDEFReaderSession` only. Never `NFCTagReaderSession`.
- Factory-blank unlocked NTAG216. Never lock or permalock the tag. Never NTAG213/215, MIFARE, LF, or UHF.
- Band tap never auto-arms SOS. SOS is full sound and full light, and arms only from the SOS · Locate Me toggle or US Crash Detection collision timing.
- `#d=` is never sent to a server, MCP, or the VPS. The VPS may serve the static tap page only. Do not log, store, or process the fragment.
- Do not put medical profile data or `#d=` payloads in commits, PRs, agent files, or chat.

Product notes: `AGENTS.md`, `.cursor/rules/nfc-hardware.mdc`.
