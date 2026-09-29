import SwiftUI
import WebKit

/// "Create Account" from Account Sync → redmed.live's own account dialog,
/// in-app (no Safari hand-off). Separate, minimal WKWebView — the
/// Passerby shell in PasserbyHTMLCardView.swift embeds locally-built
/// profile HTML strings, not a remote page, so it doesn't fit here.
/// `?account=1` is the site's own canonical URL for opening that dialog
/// directly (found in its compiled bundle) — same OTP/password Supabase
/// sign-in as this app, on redmed.live's `public.member_bands` account,
/// unrelated to this app's `redmed_owner` medical profile sync.
struct RedMedLiveAccountView: View {
    @Environment(\.dismiss) private var dismiss
    private static let accountURL = URL(string: "https://redmed.live/?account=1")!

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ChromeTextAction(title: "Close", weight: .bold) { dismiss() }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .redmedTopChromeWash()

            RedMedLiveWebView(url: Self.accountURL)
        }
        .background { RedMedPageBackground() }
    }
}

private struct RedMedLiveWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// `?account=1` opens the dialog but always on its "Sign in" tab (no URL
    /// param selects "Create account" — confirmed from the site's own
    /// compiled bundle). Selecting the tab here is this app's own script
    /// running once navigation finishes, not a change to the site itself.
    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // `?account=1` opens the dialog itself from the page's own script
            // after this navigation finishes (session restore, etc.), so the
            // dialog isn't open yet when we land here. Watch for it instead
            // of clicking once and hoping the timing lines up.
            webView.evaluateJavaScript("""
            (function() {
                var tries = 0;
                var timer = setInterval(function() {
                    tries++;
                    var dialog = document.getElementById('account-dialog');
                    var tab = document.getElementById('signup-tab');
                    if (dialog && dialog.open && tab) {
                        tab.click();
                        clearInterval(timer);
                    } else if (tries > 40) {
                        clearInterval(timer);
                    }
                }, 100);
            })();
            """)
        }
    }
}
