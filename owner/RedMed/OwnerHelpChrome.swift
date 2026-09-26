import SwiftUI

private struct ScannerSessionKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ScannerDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// True when this tree is the first-responder / scan shell (no owner edit).
    var isScannerSession: Bool {
        get { self[ScannerSessionKey.self] }
        set { self[ScannerSessionKey.self] = newValue }
    }

    /// Optional Back action when the scanner shell is presented over the owner app.
    var scannerDismiss: (() -> Void)? {
        get { self[ScannerDismissKey.self] }
        set { self[ScannerDismissKey.self] = newValue }
    }
}

/// Dismisses the Preview scanner / ped shell. Shown on RedMed, 911, and Aid
/// (NFC is owner-only — scanner chrome never mounts it).
/// Same `ChromeTextAction` as owner Edit — accent red text, no chip box.
struct ScannerBackButton: View {
    @Environment(\.scannerDismiss) private var scannerDismiss

    var body: some View {
        if let scannerDismiss {
            ChromeTextAction(title: "Back", action: scannerDismiss)
        }
    }
}

/// Top chrome row for 911 / Aid / NFC. No Help / Policies button.
/// Scanner sessions: Back only. Owner with trailing content: trailing on the right.
/// Owner with no trailing: renders nothing (content starts under the tab bar).
struct PageTopChrome<Trailing: View>: View {
    @Environment(\.isScannerSession) private var isScannerSession
    @ViewBuilder var trailing: () -> Trailing

    private var showsRow: Bool {
        isScannerSession || Trailing.self != EmptyView.self
    }

    var body: some View {
        if showsRow {
            HStack(alignment: .center, spacing: 12) {
                if isScannerSession {
                    ScannerBackButton()
                    Spacer(minLength: 0)
                    trailing()
                } else {
                    Spacer(minLength: 0)
                    trailing()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .redmedTopChromeWash()
        }
    }
}

extension PageTopChrome where Trailing == EmptyView {
    init() {
        self.trailing = { EmptyView() }
    }
}

/// Compatibility alias — call sites historically named this Help chrome.
typealias PageHelpChrome = PageTopChrome
