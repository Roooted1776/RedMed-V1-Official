import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()
    /// Band / UL ingress — presents the tap card above ConsentGate so Face ID
    /// / Before You Continue never gate tap-to-view.
    @StateObject private var bandTap = BandTapIngress()

    init() {
        // Marks process start after dyld / debugger attach.
        // Cream with no ColdLaunch lines yet = Xcode install + LLDB, not SwiftUI.
        // Multi-second app.init → firstFrame under Debug Run is usually LLDB —
        // A/B with scheme RedMed-NoDebug / Run Without Debugging.
        RedMedSignpost.coldLaunchMark("app.init")
        // Help → Settings Location toggle is gone; leftover false had no UI.
        AppSettings.migrateRemovedLocationToggle()
        // Register switcher-cover observers before the first resign (Debug
        // attach can resign before any SwiftUI .task).
        SnapshotSafeCover.activate()
        RedMedSignpost.coldMark("SnapshotSafeCover ready")
    }

    var body: some Scene {
        WindowGroup {
            PrivacySnapshotGuard {
                LaunchRoot()
            }
            .environmentObject(profile)
            .environmentObject(bandTap)
            .background(Color.redmedBg.ignoresSafeArea())
            .background(CreamWindowBackground())
            .preferredColorScheme(.light)
            .task {
                // Returning cold: Prefetch + MainActor adopt already started
                // from ProfileData.init. This is only a safety net if init
                // skipped the gate. Consent-pending must NOT adopt here —
                // that raced cream drop / ack layout (objectWillChange under
                // Before You Continue). Agree calls beginLaunchPrefetch.
                // Haptics stay in ContentView after YOU paints.
                guard ConsentSettings.hasAcceptedCurrent else { return }
                profile.beginLaunchPrefetch()
            }
            .onOpenURL { url in
                let scheme = (url.scheme ?? "").lowercased()
                let host = (url.host ?? "").lowercased()
                if scheme == "redmed", host == "nfc" {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                    return
                }
                // redmed:// is never ingested — any app can register that scheme.
                // https://redmed.live/tapper/#d= often arrives here with the
                // fragment still attached when webpageURL has already dropped it.
                if TapperWebLink.isCardURL(url) {
                    bandTap.ingest(url.absoluteString, profile: profile)
                }
            }
            // Associated Domains (applinks:) — the only band-tap path into the app.
            // The band URL stays https://redmed.live/tapper/#d= on the VPS.
            // Owner account sync stays in Supabase. This callback only opens
            // the bundled tapper.html. It does not fetch or store the fragment.
            // Any decodable `#d=` — including the wearer's own band — opens
            // the ungated tap card (no Face ID, no Before You Continue, no
            // Keychain write, no SOS). A missing or undecodable fragment stays
            // quiet. Phones without RedMed keep Safari on the VPS page.
            // One UL callback often drops `#d=`. Prefer whichever candidate
            // still decodes. Band tap never arms SOS.
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let urlString = TapperWebLink.cardURLString(from: activity) else { return }
                bandTap.ingest(urlString, profile: profile)
            }
        }
    }
}

/// https card URLs for the write-base host only. `redmed://` never qualifies.
enum TapperWebLink {
    static func isCardURL(_ url: URL) -> Bool {
        guard (url.scheme ?? "").lowercased() == "https" else { return false }
        let path = url.path.lowercased()
        guard path == "/tapper" || path.hasPrefix("/tapper/") else { return false }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return false }
        return allowedHosts.contains(host)
    }

    /// Prefer a string that still decodes `#d=`. `webpageURL` sometimes omits
    /// the fragment; `onOpenURL` and `userInfo` can still carry it.
    static func cardURLString(from activity: NSUserActivity) -> String? {
        let page = activity.webpageURL
        var candidates: [String] = []
        if let page, isCardURL(page) {
            candidates.append(page.absoluteString)
        }
        if let info = activity.userInfo {
            for value in info.values {
                let string: String?
                if let text = value as? String {
                    string = text
                } else if let url = value as? URL {
                    string = url.absoluteString
                } else {
                    string = nil
                }
                guard let string, let url = URL(string: string), isCardURL(url) else { continue }
                // A userInfo URL has to be the same card as webpageURL. That
                // keeps a stray string in the activity from replacing the tap.
                if let page {
                    guard url.host?.lowercased() == page.host?.lowercased(),
                          url.path.lowercased() == page.path.lowercased() else { continue }
                }
                candidates.append(string)
            }
        }
        let decoded = candidates.filter { candidate in
            guard let url = URL(string: candidate), isCardURL(url) else { return false }
            return ProfileNFCCodec.decodeProfile(fromURLString: candidate) != nil
        }
        if let hit = decoded.first { return hit }
        return candidates.first { candidate in
            guard let url = URL(string: candidate) else { return false }
            return isCardURL(url)
        }
    }

    private static var allowedHosts: Set<String> {
        guard let base = URL(string: AppConfig.medicalCardBaseURL),
              let host = base.host?.lowercased(), !host.isEmpty else {
            return ["redmed.live", "www.redmed.live"]
        }
        var hosts: Set<String> = [host]
        if host.hasPrefix("www.") {
            hosts.insert(String(host.dropFirst(4)))
        } else {
            hosts.insert("www." + host)
        }
        return hosts
    }
}

/// In-app band / Universal Link tap card. Lives above `ConsentGateView` so
/// tap-to-view never hits Face ID, login, or Before You Continue.
@MainActor
final class BandTapIngress: ObservableObject {
    struct Session: Identifiable, Equatable {
        let id = UUID()
        let urlString: String
    }

    @Published var session: Session?
    /// URL waiting on Keychain restore before own-match vs foreign decision.
    private var queuedURL: String?

    /// True while an ungated band tap card is up — ConsentGate must not Face ID.
    var isPresentingTapCard: Bool { session != nil }

    func ingest(_ urlString: String, profile: ProfileData) {
        guard ProfileNFCCodec.decodeProfile(fromURLString: urlString) != nil else {
            // Bad / missing `#d=` → quiet foreground only.
            return
        }
        // Own-match needs RAM. Queue while Keychain restore is in flight so
        // the wearer's own band does not flash a passerby sheet.
        if profile.isRestoringFromKeychain {
            queuedURL = urlString
            return
        }
        decide(urlString, profile: profile)
    }

    /// Call when Keychain restore settles (`isRestoringFromKeychain` → false).
    func profileRestoreDidSettle(profile: ProfileData) {
        guard let url = queuedURL else { return }
        queuedURL = nil
        decide(url, profile: profile)
    }

    private func decide(_ urlString: String, profile _: ProfileData) {
        guard ProfileNFCCodec.decodeProfile(fromURLString: urlString) != nil else {
            return
        }
        // Bundled tapper.html. The NDEF URL is still the VPS page, and the
        // owner database is not read or written here. No Face ID, no
        // ConsentGate, no Keychain write, no SOS.
        open(urlString)
    }

    private func open(_ urlString: String) {
        _ = BiometricAuth.cancelInFlight()
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            session = Session(urlString: urlString)
        }
    }

    func dismiss() {
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            session = nil
        }
    }
}

/// First launch (or policy-version bump): Before you continue (Agree only),
/// then Face ID while Main warms, then Main interactive. Later cold starts
/// skip Before You Continue but still Face ID once on cream over warm Main
/// (Keychain restore / prefetch already racing underneath — no fixed sleep).
/// Same-session resume does not re-prompt. No OwnerAppLock relock. Passerby
/// tapper is not in this tree — band / UL tap cards present above the gate.
private struct LaunchRoot: View {
    @EnvironmentObject private var profile: ProfileData
    @EnvironmentObject private var bandTap: BandTapIngress
    /// Returning opens: no SwiftUI cream veil — UILaunchScreen already matches
    /// and ConsentGate paints Face ID cream over armed Main. First launch
    /// (or after Erase / policy bump): flat cream for SplashBoard → Agree
/// layout, dropped after one yield. Page rose wash waits for `.active` then
/// a short settle so it does not fight that drop or a returning Keychain adopt.
    @State private var holdLaunchCream = !ConsentSettings.hasAcceptedCurrent

    var body: some View {
        ZStack {
            ConsentGateView { Main() }

            if holdLaunchCream {
                Color.redmedBg
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            // Ends coldLaunchWindow at firstFrame (app.init → first paint).
            // Lag *before* app.init (no ColdLaunch lines) is install/attach.
            RedMedSignpost.coldLaunchFirstFrameOnce()
            // Main-ready is ConsentGate after Face ID (returning and fresh).
            // Flush a band URL queued during restore if settle already happened.
            if !profile.isRestoringFromKeychain {
                bandTap.profileRestoreDidSettle(profile: profile)
            }
        }
        .task {
            guard holdLaunchCream else { return }
            await Task.yield()
            var t = Transaction()
            t.animation = nil
            withTransaction(t) { holdLaunchCream = false }
            RedMedSignpost.coldMark("cream dropped")
        }
        // Restore settled → flush queued band URL (own-match quiet vs card).
        .onChange(of: profile.isRestoringFromKeychain) { _, restoring in
            if !restoring {
                bandTap.profileRestoreDidSettle(profile: profile)
            }
        }
        // Ungated tap card above ConsentGate / Face ID / Before You Continue.
        .fullScreenCover(item: Binding(
            get: { bandTap.session },
            set: { bandTap.session = $0 }
        )) { session in
            PasserbyHTMLCardView(
                payloadOrURL: session.urlString,
                braceletLinked: false,
                embedProfileJSON: nil
            )
            .environment(\.isScannerSession, true)
            .presentationBackground(Color.redmedBg)
        }
    }
}
