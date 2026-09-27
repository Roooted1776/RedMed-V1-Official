import SwiftUI
import WebKit
import UIKit

/// Bundled owner Help: one HTML file, five in-doc anchors. Offline. No network.
enum HelpDocument {
    static let bundledFile = "Document"
    /// Section header on Help (owner + scanner) and Before You Continue.
    /// Each Policy is its own row — not one combined Policies button.
    static let combinedTitle = "Policies"
    /// Nav titles are plain text; row icons are SF Symbols (Document.html keeps its own emoji).
    static var combinedMarkedTitle: String { combinedTitle }
    static let defaultPolicy: Policy = .privacy

    enum Policy: String, CaseIterable, Identifiable {
        case privacy
        case security
        case terms
        case medicalDisclaimer
        case shipsWhenReady

        var id: String { rawValue }

        var title: String {
            switch self {
            case .privacy: return "Privacy"
            case .security: return "Security"
            case .terms: return "Terms"
            case .medicalDisclaimer: return "Medical Disclaimer"
            case .shipsWhenReady: return "Ships When Ready"
            }
        }

        /// Row icon — SF Symbol, vector-sharp (was emoji).
        var symbol: String {
            switch self {
            case .privacy: return "hand.raised.fill"
            case .security: return "lock.shield.fill"
            case .terms: return "doc.text.fill"
            case .medicalDisclaimer: return "cross.case.fill"
            case .shipsWhenReady: return "shippingbox.fill"
            }
        }

        var markedTitle: String { title }

        var fragment: String {
            switch self {
            case .medicalDisclaimer: return "medical-disclaimer"
            case .shipsWhenReady: return "ships-when-ready"
            default: return rawValue
            }
        }

        static func matching(fragment: String) -> Policy? {
            allCases.first { $0.fragment == fragment }
        }
    }
}

// MARK: - Policy WKWebView pool (Before You Continue + Help)
/// Pre-parses bundled `Document.html` so the first Policies tap is not a
/// cold WKWebView spin. ConsentGate warms while the ack text is on screen;
/// Agree discards so this does not race Main / Face ID. Help can take the
/// same spare if one is still sitting idle.
@MainActor
enum PolicyWebViewPool {
    private static var warmed: WKWebView?
    private static var warming: WKWebView?
    private static var warmTask: Task<WKWebView?, Never>?

    static func warm() {
        _ = ensureWarmTask()
    }

    static func discard() {
        warmTask?.cancel()
        warmTask = nil
        if let warming {
            warming.stopLoading()
            warming.navigationDelegate = nil
            self.warming = nil
        }
        if let warmed {
            warmed.stopLoading()
            warmed.navigationDelegate = nil
            self.warmed = nil
        }
    }

    /// Finished Document.html only — mid-load handoff leaves a blank sheet.
    static func take() -> WKWebView? {
        guard let view = warmed else { return nil }
        guard !view.isLoading, view.url != nil else { return nil }
        warmed = nil
        warmTask = nil
        return view
    }

    private static func ensureWarmTask() -> Task<WKWebView?, Never> {
        if let warmed {
            return Task { @MainActor in warmed }
        }
        if let warmTask { return warmTask }
        let task = Task<WKWebView?, Never> { @MainActor in
            if Task.isCancelled { return .none }
            guard let url = Bundle.main.url(
                forResource: HelpDocument.bundledFile,
                withExtension: "html"
            ) else { return .none }
            if Task.isCancelled { return .none }

            let webView = makeConfiguredWebView(navigationDelegate: nil)
            warming = webView
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            // Wait until parse finishes so take() can hand off a painted doc.
            // Cap ~1s — ack reading time is longer; miss falls back to cold load.
            for _ in 0..<50 {
                if Task.isCancelled { break }
                if !webView.isLoading, webView.url != nil { break }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            if Task.isCancelled {
                webView.stopLoading()
                webView.navigationDelegate = nil
                if warming === webView { warming = nil }
                return .none
            }
            warming = nil
            warmed = webView
            return webView
        }
        warmTask = task
        Task { @MainActor in
            _ = await task.value
            if warmTask == task { warmTask = nil }
        }
        return task
    }

    static func makeConfiguredWebView(navigationDelegate: WKNavigationDelegate?) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Bundled Document.html — no cookies / SW disk on first Policies open.
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let cream = UIColor(Color.redmedBg)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = navigationDelegate
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.isOpaque = true
        webView.backgroundColor = cream
        webView.scrollView.isOpaque = true
        webView.scrollView.backgroundColor = cream
        webView.underPageBackgroundColor = cream
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.redmedLockPageZoom()
        return webView
    }
}

// MARK: - WebView wrapper (bundled Help / policy HTML only)
struct LocalWebView: UIViewRepresentable {
    let filename: String
    var fragment: String? = nil
    /// Document.html section id — optional native hook when the sticky nav jumps.
    var onPolicyChange: ((HelpDocument.Policy) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        // Prefer a finished Before-You-Continue warm of Document.html.
        if filename == HelpDocument.bundledFile,
           let pooled = PolicyWebViewPool.take() {
            pooled.configuration.userContentController.add(
                context.coordinator,
                name: "rmPolicy"
            )
            pooled.navigationDelegate = context.coordinator
            context.coordinator.usingPooled = true
            context.coordinator.didLoadHTML = true
            context.coordinator.loadedKey = "\(filename)#\(fragment ?? "")"
            context.coordinator.fragment = fragment
            context.coordinator.onPolicyChange = onPolicyChange
            pooled.redmedLockPageZoom()
            return pooled
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "rmPolicy")
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let cream = UIColor(Color.redmedBg)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        // Same opaque cream as passerby shell — avoid system white flash.
        webView.isOpaque = true
        webView.backgroundColor = cream
        webView.scrollView.isOpaque = true
        webView.scrollView.backgroundColor = cream
        webView.underPageBackgroundColor = cream
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.redmedLockPageZoom()
        return webView
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "rmPolicy")
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let key = "\(filename)#\(fragment ?? "")"
        context.coordinator.fragment = fragment
        context.coordinator.onPolicyChange = onPolicyChange

        if context.coordinator.usingPooled {
            context.coordinator.usingPooled = false
            // Already parsed — jump to start section without a second file load.
            context.coordinator.scrollToFragment(in: webView)
            return
        }

        if context.coordinator.loadedKey == key { return }

        let loadedFile = context.coordinator.loadedKey?
            .split(separator: "#", maxSplits: 1)
            .first
            .map(String.init)
        if loadedFile == filename, context.coordinator.didLoadHTML {
            context.coordinator.loadedKey = key
            context.coordinator.scrollToFragment(in: webView)
            return
        }

        guard let url = Bundle.main.url(forResource: filename, withExtension: "html") else { return }
        context.coordinator.loadedKey = key
        context.coordinator.didLoadHTML = true
        // Real file load so #privacy / #terms / #security and sibling Document.html
        // links resolve. loadHTMLString blocked those as local-resource navigations.
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    /// Policy HTML + stylesheet only — never lateral loads into tapper.html.
    private static let allowedFileBasenames: Set<String> = [
        "Document.html",
        "legal-doc.css"
    ]

    /// Passerby shell filenames. Open the hosted card in Safari — do not dump
    /// an empty tapper.html into the Help webview.
    private static let passerbyShellFiles: Set<String> = [
        "tapper.html",
        "index.html",
        "card.html"
    ]

    /// Blocks in-webview navigation to untrusted schemes; opens http(s)/tel/mailto/redmed externally.
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var loadedKey: String?
        var fragment: String?
        var didLoadHTML = false
        /// True for one update after `PolicyWebViewPool.take()` — skip reload.
        var usingPooled = false
        var onPolicyChange: ((HelpDocument.Policy) -> Void)?

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "rmPolicy", let raw = message.body as? String else { return }
            reportPolicy(raw)
        }

        func reportPolicy(_ fragment: String) {
            let safe = fragment.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            guard safe == fragment, let policy = HelpDocument.Policy.matching(fragment: safe) else { return }
            DispatchQueue.main.async { self.onPolicyChange?(policy) }
        }

        func scrollToFragment(in webView: WKWebView) {
            guard let fragment else {
                // Combined Policies open: letterhead + notice + nav at y=0.
                // Jumping to #privacy skips that top matter (scroll-margin + sticky nav).
                scrollToDocumentTop(in: webView)
                return
            }
            jumpToPolicyFragment(fragment, in: webView)
        }

        func scrollToDocumentTop(in webView: WKWebView) {
            webView.scrollView.setContentOffset(.zero, animated: false)
            // Mark Privacy in the sticky nav without scrolling past the letterhead.
            webView.evaluateJavaScript(
                """
                (function(){
                  if (typeof window.__rmShowPolicy === 'function') {
                    window.__rmShowPolicy('privacy', false);
                  }
                  window.scrollTo(0, 0);
                  try {
                    if (document.documentElement) document.documentElement.scrollTop = 0;
                    if (document.body) document.body.scrollTop = 0;
                  } catch (e0) {}
                  try { history.replaceState(null, '', location.pathname + location.search); } catch (e1) {}
                })();
                """
            )
        }

        func jumpToPolicyFragment(_ id: String, in webView: WKWebView) {
            let safe = id.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            guard safe == id, !safe.isEmpty else { return }
            // replaceState, not location.hash — assigning hash can reload the file.
            // window.__rmShowPolicy (defined in Document.html) scrolls to the
            // section in the continuous document; fall back to a plain
            // scroll if the page's own script hasn't run yet for some reason.
            webView.evaluateJavaScript(
                """
                (function(){
                  var id = '\(safe)';
                  if (typeof window.__rmShowPolicy === 'function') {
                    window.__rmShowPolicy(id, true);
                  } else {
                    var el = document.getElementById(id);
                    if (el) el.scrollIntoView({block:'start'});
                  }
                  try { history.replaceState(null, '', '#' + id); } catch (e) {}
                })();
                """
            )
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.redmedLockPageZoom()
            webView.scrollView.flashScrollIndicators()
            scrollToFragment(in: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.isFileURL {
                let name = url.lastPathComponent
                if LocalWebView.passerbyShellFiles.contains(name) {
                    if let hosted = Self.hostedPasserbyURL(from: url) {
                        UIApplication.shared.open(hosted, options: [:], completionHandler: nil)
                    }
                    decisionHandler(.cancel)
                    return
                }
                if navigationAction.navigationType == .linkActivated,
                   let dest = Self.policyDestination(file: name, fragment: url.fragment),
                   isShowingHelp(webView) {
                    decisionHandler(.cancel)
                    fragment = dest
                    reportPolicy(dest)
                    jumpToPolicyFragment(dest, in: webView)
                    return
                }
                if LocalWebView.allowedFileBasenames.contains(name) {
                    if let dest = url.fragment, !dest.isEmpty {
                        fragment = dest
                    }
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }
                return
            }
            let scheme = (url.scheme ?? "").lowercased()
            switch scheme {
            case "http", "https", "mailto", "tel", "redmed":
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
            default:
                decisionHandler(.cancel)
            }
        }

        private func isShowingHelp(_ webView: WKWebView) -> Bool {
            if webView.url?.lastPathComponent == "Document.html" { return true }
            if loadedKey?.split(separator: "#", maxSplits: 1).first.map(String.init) == "Document" {
                return true
            }
            return false
        }

        /// AppConfig write base + any `#d=` / search from a bundled tapper.html tap.
        private static func hostedPasserbyURL(from fileURL: URL) -> URL? {
            var raw = AppConfig.medicalCardBaseURL
            if let query = fileURL.query, !query.isEmpty {
                let sep = raw.contains("?") ? "&" : "?"
                raw += sep + query
            }
            if let fragment = fileURL.fragment, !fragment.isEmpty {
                raw += "#" + fragment
            }
            return URL(string: raw)
        }

        private static let helpFragments: Set<String> = Set(HelpDocument.Policy.allCases.map(\.fragment))

        private static func policyDestination(file: String, fragment: String?) -> String? {
            guard file == "Document.html", let fragment, helpFragments.contains(fragment) else {
                return nil
            }
            return fragment
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Deny target=_blank / window.open — no popup webviews from policy HTML.
            if let url = navigationAction.request.url,
               !url.isFileURL {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return nil
        }
    }
}

// MARK: - Policies document (Help push + Before You Continue sheet)
/// One WebView for the combined Policies document. Help and Before You Continue
/// both open per-document rows via `pageTitle` / `startAt` (deep-link that section).
struct HelpPolicyPage: View {
    var startAt: HelpDocument.Policy? = nil
    var showsDoneChrome: Bool = false
    var onDone: (() -> Void)? = nil
    /// Sheet / nav title. Nil → combined Policies fallback. Per-doc rows pass the section title.
    var pageTitle: String? = nil

    private var resolvedTitle: String {
        pageTitle ?? startAt?.markedTitle ?? HelpDocument.combinedMarkedTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDoneChrome {
                OwnerModalChrome(
                    title: resolvedTitle,
                    leadingTitle: "Done",
                    leadingAction: { onDone?() }
                )
            }
            LocalWebView(
                filename: HelpDocument.bundledFile,
                fragment: startAt?.fragment
            )
        }
        .background { RedMedPageBackground() }
        .navigationTitle(resolvedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showsDoneChrome ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(Color.redmedBg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

/// Leading icon for Help rows — SF Symbol in accent red, same slot the emoji used.
struct HelpRowIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.redmedAccent)
            .frame(width: 22, alignment: .center)
            .accessibilityHidden(true)
    }
}

/// Trailing chevron for every Help row that opens something.
struct HelpRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.redmedMuted.opacity(0.55))
            .accessibilityHidden(true)
    }
}

/// One policy section row (Help menu + Before You Continue).
struct HelpPolicyRowLabel: View {
    let policy: HelpDocument.Policy
    var titleWeight: Font.Weight = .medium

    var body: some View {
        HStack(spacing: 10) {
            HelpRowIcon(symbol: policy.symbol)
            Text(policy.title)
                .font(.system(size: RedMedChrome.rowFont, weight: titleWeight))
                .foregroundColor(.redmedDark)
            Spacer(minLength: 0)
            HelpRowChevron()
        }
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.vertical, RedMedChrome.rowVPad)
        .contentShape(Rectangle())
    }
}

// MARK: - Help menu
struct HelpMenuView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.isScannerSession) private var isScannerSession
    @EnvironmentObject private var profile: ProfileData
    /// Settings (Haptic feedback) lives on `ConsentGateView`. Location is on as part of Agree.
    @ObservedObject private var locationSuggester = LocationAccessSuggester.shared
    var onOpenNFC: (() -> Void)? = nil

    @State private var showEraseConfirm = false
    @State private var isErasing = false
    @State private var eraseAuthFailed = false
    @State private var eraseIncomplete = false
    @State private var authUnavailableMessage: String?

    /// Same metrics as Edit — even horizontal rhythm across Help / Edit.
    private enum Metrics {
        static let font: CGFloat = 15
        static let rowHPad: CGFloat = RedMedChrome.pagePadX
        static let rowVPad: CGFloat = 13
        static let sectionGap: CGFloat = 22
    }

    /// Owner-only: Erase, Write to NFC. Scanner Help is policies only.
    /// Settings (Haptic feedback) lives on `ConsentGateView` now. Location is on as part of Agree.
    private var showsOwnerTools: Bool { !isScannerSession }

    private var firstHelpSection: String {
        if showsOwnerTools { return "Common Questions" }
        return "Policies"
    }

    /// Band setup lives on the NFC tab (copy in `AppConfig.NFCWriteCopy`).
    private var bandRowTitle: String { AppConfig.NFCWriteCopy.helpBandRowTitle }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OwnerModalChrome(
                    title: "Help",
                    leadingTitle: "Done",
                    leadingAction: { dismiss() }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if showsOwnerTools {
                            helpSectionLabel("Common Questions")
                            helpCard(flatten: false) {
                                ForEach(Array(AppConfig.HelpQuestions.all.enumerated()), id: \.offset) { index, item in
                                    if index > 0 {
                                        Divider().overlay(Color.redmedDivider)
                                    }
                                    HelpQuestionRow(question: item.question, answer: item.answer)
                                }
                            }
                        }

                        if showsOwnerTools, let onOpenNFC {
                            helpSectionLabel("Bracelet")
                            helpCard {
                                Button {
                                    onOpenNFC()
                                } label: {
                                    HStack(spacing: 10) {
                                        HelpRowIcon(symbol: "wave.3.right")
                                        Text(bandRowTitle)
                                            .font(.system(size: Metrics.font, weight: .medium))
                                            .foregroundColor(.redmedDark)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        HelpRowChevron()
                                    }
                                    .padding(.horizontal, Metrics.rowHPad)
                                    .padding(.vertical, Metrics.rowVPad)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(bandRowTitle)
                                .accessibilityHint("Opens NFC")
                            }
                        }

                        helpSectionLabel("Policies")
                        helpCard {
                            ForEach(Array(HelpDocument.Policy.allCases.enumerated()), id: \.element.id) { index, policy in
                                if index > 0 {
                                    Divider().overlay(Color.redmedDivider)
                                }
                                NavigationLink {
                                    HelpPolicyPage(
                                        startAt: policy,
                                        pageTitle: policy.markedTitle
                                    )
                                } label: {
                                    HelpPolicyRowLabel(policy: policy)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(policy.title)
                                .accessibilityHint("Opens \(policy.title)")
                            }
                        }

                        // Owner only — a helper's Help stays policies-only.
                        if showsOwnerTools {
                            helpSectionLabel("Support")
                            helpCard {
                                Button {
                                    if let url = Self.supportMailURL { openURL(url) }
                                } label: {
                                    HStack(spacing: 10) {
                                        HelpRowIcon(symbol: "envelope.fill")
                                        Text("Contact Support")
                                            .font(.system(size: Metrics.font, weight: .medium))
                                            .foregroundColor(.redmedDark)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        HelpRowChevron()
                                    }
                                    .padding(.horizontal, Metrics.rowHPad)
                                    .padding(.vertical, Metrics.rowVPad)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Contact Support")
                                .accessibilityHint("Opens an email to \(AppConfig.supportEmail)")
                            }
                            Text("App or band questions: \(AppConfig.supportEmail). Don't email your full medical ID.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.redmedMuted)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                        }

                        if showsOwnerTools {
                            helpSectionLabel("Data")
                            helpCard {
                                if ProfileCloudSync.isAvailable {
                                    NavigationLink {
                                        OwnerAccountView()
                                    } label: {
                                        HStack(spacing: 10) {
                                            HelpRowIcon(symbol: "icloud.fill")
                                            Text("Account sync")
                                                .font(.system(size: Metrics.font, weight: .medium))
                                                .foregroundColor(.redmedDark)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            HelpRowChevron()
                                        }
                                        .padding(.horizontal, Metrics.rowHPad)
                                        .padding(.vertical, Metrics.rowVPad)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().overlay(Color.redmedDivider)
                                }
                                Button(role: .destructive) {
                                    showEraseConfirm = true
                                } label: {
                                    Group {
                                        if isErasing {
                                            ProgressView()
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            HStack(spacing: 10) {
                                                HelpRowIcon(symbol: "trash.fill")
                                                Text("Erase All User Data")
                                                    .font(.system(size: Metrics.font, weight: .medium))
                                                    .foregroundColor(.redmedAccent)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, Metrics.rowHPad)
                                    .padding(.vertical, Metrics.rowVPad)
                                    .contentShape(Rectangle())
                                }
                                .disabled(isErasing)
                                .accessibilityLabel("Erase All User Data")
                            }
                            Text(ProfileCloudSync.isAvailable
                                 ? "Removes your medical ID from this iPhone and, if you’re signed in, from your account. Your band keeps its last write until you rewrite it."
                                 : "Removes your medical ID from this iPhone. Your band keeps its last write until you rewrite it.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.redmedMuted)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                        }

                        if let appVersionLine = Self.appVersionLine {
                            Text(appVersionLine)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.redmedMuted)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, Metrics.sectionGap)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, Metrics.rowHPad)
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.visible)
            }
            .background { RedMedPageBackground() }
            .tint(.redmedAccent)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                // Warm Document.html while the Help list is on screen.
                PolicyWebViewPool.warm()
                guard showsOwnerTools else { return }
                locationSuggester.refresh()
            }
            .confirmationDialog(
                "Erase All User Data On This iPhone?",
                isPresented: $showEraseConfirm,
                titleVisibility: .visible
            ) {
                Button("Erase Everything", role: .destructive) {
                    requestErase()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Face ID or passcode is required. Profile is removed from this phone. The bracelet still holds its last write until you overwrite or discard it.")
            }
            .alert("Couldn't verify it's you", isPresented: $eraseAuthFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Face ID, Touch ID, or passcode is required to erase RedMed data.")
            }
            .alert("Couldn't erase all data", isPresented: $eraseIncomplete) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The medical ID may still be on this iPhone. Try Erase again.")
            }
            .alert(BiometricAuth.unavailableAlertTitle, isPresented: Binding(
                get: { authUnavailableMessage != nil },
                set: { if !$0 { authUnavailableMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authUnavailableMessage ?? "")
            }
        }
    }

    /// mailto: with the app version in the subject so support knows the build.
    private static let supportMailURL: URL? = {
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = AppConfig.supportEmail
        parts.queryItems = [URLQueryItem(name: "subject", value: "RedMed Support · \(appVersionLine ?? "RedMed")")]
        return parts.url
    }()

    /// "RedMed 1.0 (7)" — what to quote when reporting a problem. Fixed per launch.
    private static let appVersionLine: String? = {
        let info = Bundle.main.infoDictionary
        guard let version = info?["CFBundleShortVersionString"] as? String else { return nil }
        let build = info?["CFBundleVersion"] as? String
        return build.map { "RedMed \(version) (\($0))" } ?? "RedMed \(version)"
    }()

    @ViewBuilder
    private func helpSectionLabel(_ text: String) -> some View {
        SectionLabel(text: text)
            .padding(.top, text == firstHelpSection ? 0 : Metrics.sectionGap)
    }

    @ViewBuilder
    private func helpCard<Content: View>(
        flatten: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) { content() }
            .redmedBox(flatten: flatten)
    }

    private func requestErase() {
        guard showsOwnerTools, !isErasing else { return }
        isErasing = true
        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to erase all user data on this iPhone.",
            force: true
        ) { outcome in
            switch outcome {
            case .success:
                if profile.eraseAllLocalData() {
                    RedMedHaptics.success()
                    isErasing = false
                    dismiss()
                } else {
                    RedMedHaptics.error()
                    isErasing = false
                    eraseIncomplete = true
                }
            case .notVerified:
                RedMedHaptics.error()
                isErasing = false
                eraseAuthFailed = true
            case .unavailable(let reason):
                RedMedHaptics.error()
                isErasing = false
                authUnavailableMessage = reason.message
            case .declined, .notInteractive, .timedOut:
                isErasing = false
            }
        }
    }
}

/// One Common Questions row: question on the row, answer tucked under it.
/// Same row metrics as the other Help rows; chevron turns instead of pushing.
private struct HelpQuestionRow: View {
    let question: String
    let answer: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(RedMedMotion.snappy) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Text(question)
                        .font(.system(size: RedMedChrome.rowFont, weight: .medium))
                        .foregroundColor(.redmedDark)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedMuted.opacity(0.55))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .padding(.top, 3)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.vertical, RedMedChrome.rowVPad)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(question)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityHint(expanded ? "Hides the answer" : "Shows the answer")

            if expanded {
                Text(answer)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, RedMedChrome.pagePadX)
                    .padding(.bottom, RedMedChrome.rowVPad)
                    .transition(.opacity)
            }
        }
    }
}
