import SwiftUI

/// Email one-time code for the wearer account. Hidden unless
/// `ProfileCloudSync.isAvailable`. Sign in with Apple waits on the paid team.
/// The session JWT stays in Keychain. The band is not rewritten from here.
struct OwnerAccountView: View {
    @EnvironmentObject private var profile: ProfileData
    @ObservedObject private var status = CloudSyncStatus.shared

    private enum Step { case email, code }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var busy = false
    @State private var note: String?
    @State private var noteIsError = false
    @State private var resendAvailableAt: Date?
    @State private var confirmSignOut = false
    @State private var confirmSignOutAll = false
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field { case email, code }

    private var signedIn: Bool {
        status.email != nil || ProfileCloudSync.isSignedIn
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                if signedIn {
                    signedInCard
                    bandCard
                    manageCard
                } else {
                    signInCard
                }
                if let note {
                    Text(note)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(noteIsError ? .redmedAccent : .redmedMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                privacyCard
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { RedMedPageBackground() }
        .navigationTitle("Account Sync")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.redmedBg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear { status.refresh() }
        .confirmationDialog(
            "Sign out of account sync?",
            isPresented: $confirmSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) { Task { await signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("RedMed stays on this iPhone and on the band. Edits stop syncing until you sign in again.")
        }
        .confirmationDialog(
            "Sign out on every device?",
            isPresented: $confirmSignOutAll,
            titleVisibility: .visible
        ) {
            Button("Sign Out All Devices", role: .destructive) { Task { await signOutAll() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use this if a phone signed in to this account is lost or sold. Every device, including this iPhone, has to sign in again. RedMed on each phone and any band stay as they are.")
        }
        .confirmationDialog(
            "Delete this account?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes your sign-in and the account copy of your card. This can't be undone. RedMed on this iPhone and your band are not changed. To also clear this iPhone, use Help → Erase All User Data.")
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.redmedAccent)
                .frame(width: 40, height: 40)
                .background(Color.redmedWash.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Wearer copy")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.redmedDark)
                    Spacer(minLength: 0)
                    statusPill
                }
                Text("Keeps your RedMed on your sign-in so a new iPhone can load it. The band and the tap page never look it up.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .redmedBox()
        .accessibilityElement(children: .combine)
    }

    private var statusPill: some View {
        let (label, color) = pillStyle
        return HStack(spacing: 6) {
            if status.phase == .syncing {
                ProgressView().controlSize(.mini).tint(.redmedMuted)
            } else {
                Circle().fill(color).frame(width: 7, height: 7)
            }
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.redmedDark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.redmedBg)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.redmedDivider, lineWidth: 1))
    }

    private var pillStyle: (String, Color) {
        switch status.phase {
        case .off: return ("Off", .redmedMuted.opacity(0.5))
        case .signedOut: return ("Signed out", .redmedMuted.opacity(0.5))
        case .syncing: return ("Syncing", .redmedMuted)
        case .failed: return ("Needs retry", .redmedAccent)
        case .idle: return ("Up to date", .green)
        }
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: step == .email ? "Sign in" : "Enter code")
            switch step {
            case .email:
                inputField(
                    "Email",
                    text: $email,
                    field: .email,
                    content: .emailAddress,
                    keyboard: .emailAddress
                )
                .submitLabel(.send)
                .onSubmit { Task { await send() } }
                PrimaryButton(
                    title: "Email Me a Code",
                    systemImage: "envelope.fill",
                    busy: busy,
                    disabled: !emailLooksValid
                ) {
                    Task { await send() }
                }
            case .code:
                Text("We sent a code to \(trimmedEmail).")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                inputField(
                    "6-digit code",
                    text: $code,
                    field: .code,
                    content: .oneTimeCode,
                    keyboard: .numberPad
                )
                .onChange(of: code) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(10))
                    if digits != value { code = digits }
                }
                PrimaryButton(
                    title: "Verify Code",
                    systemImage: "checkmark.shield.fill",
                    busy: busy,
                    disabled: trimmedCode.count < 6
                ) {
                    Task { await verify() }
                }
                HStack {
                    ChromeTextAction(title: "Use a different email") {
                        step = .email
                        code = ""
                        note = nil
                        focus = .email
                    }
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let wait = resendWait(now: context.date)
                        ChromeTextAction(title: wait > 0 ? "Resend in \(wait)s" : "Resend") {
                            Task { await send() }
                        }
                        .disabled(wait > 0 || busy)
                        .opacity(wait > 0 ? RedMedChrome.disabledOpacity : 1)
                    }
                }
                .font(.system(size: 14))
            }
        }
        .padding(16)
        .redmedBox(flatten: false)
    }

    private var signedInCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Account")
                .padding(.top, 14)
                .padding(.horizontal, 12)
            infoRow(icon: "person.crop.circle", title: "Signed in", detail: status.email ?? "Email hidden")
            rule
            infoRow(icon: "clock.arrow.circlepath", title: "Last synced", detail: lastSyncedText)
            if case .failed(let message) = status.phase {
                rule
                infoRow(icon: "exclamationmark.triangle.fill", title: "Last try", detail: message, tint: .redmedAccent)
            }
            VStack(spacing: 10) {
                OutlineButton(
                    title: status.phase == .syncing ? "Syncing…" : "Sync Now",
                    systemImage: "arrow.triangle.2.circlepath",
                    busy: status.phase == .syncing
                ) {
                    Task { await ProfileCloudSync.pullIfNeeded(into: profile) }
                }
                Button(role: .destructive) {
                    confirmSignOut = true
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .disabled(busy)
            }
            .padding(12)
        }
        .redmedBox()
    }

    private var bandCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Band")
                .padding(.top, 14)
                .padding(.horizontal, 12)
            infoRow(
                icon: "wave.3.right",
                title: "Last verified write",
                detail: ProfileCloudSync.lastVerifiedBandWriteAt.map(relative) ?? "Not on this iPhone"
            )
            if profile.accountNewerThanBand {
                rule
                infoRow(
                    icon: "exclamationmark.circle.fill",
                    title: "Band is behind",
                    detail: "The account copy changed after the last band write. Write The Band on the NFC tab so helpers see the same card.",
                    tint: .redmedAccent
                )
            }
        }
        .padding(.bottom, 4)
        .redmedBox()
    }

    private var manageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Manage")
                .padding(.top, 14)
                .padding(.horizontal, 12)
            manageRow(
                icon: "iphone.slash",
                title: "Sign Out All Devices",
                detail: "Lost or sold a phone? End every session on this account."
            ) {
                confirmSignOutAll = true
            }
            rule
            manageRow(
                icon: "trash",
                title: "Delete Account",
                detail: "Removes the sign-in and the account copy for good."
            ) {
                confirmDelete = true
            }
        }
        .padding(.bottom, 4)
        .redmedBox()
    }

    private func manageRow(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button {
            RedMedHaptics.light()
            action()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.redmedMuted.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? RedMedChrome.disabledOpacity : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var privacyCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                privacyLine("Stored: the fields on your RedMed card, tied to your sign-in only. Row-level security blocks every other account.")
                privacyLine("Not stored: the band's #d= link. A verified write logs only a SHA-256 of it and its size.")
                privacyLine("The public tap page and helpers' phones never call this account.")
                privacyLine("Erase All User Data deletes the account copy too. If you're offline, RedMed finishes the delete next time it connects.")
                privacyLine("Delete Account removes the sign-in and everything stored under it. It needs a connection and tells you if it didn't happen.")
            }
            .padding(.top, 8)
        } label: {
            Text("What syncs")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.redmedMuted)
        }
        .tint(.redmedAccent)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .redmedBox()
    }

    // MARK: - Pieces

    private func inputField(
        _ placeholder: String,
        text: Binding<String>,
        field: Field,
        content: UITextContentType,
        keyboard: UIKeyboardType
    ) -> some View {
        TextField(placeholder, text: text)
            .textContentType(content)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focus, equals: field)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.redmedDark)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.redmedBg)
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous)
                    .strokeBorder(focus == field ? Color.redmedAccent.opacity(0.55) : Color.redmedDivider, lineWidth: 1.2)
            )
    }

    private func infoRow(icon: String, title: String, detail: String, tint: Color = .redmedDark) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint == .redmedDark ? .redmedAccent : tint)
                .frame(width: 24)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private func privacyLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.redmedAccent).frame(width: 5, height: 5).padding(.top, 6)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedDark)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rule: some View {
        Divider().overlay(Color.redmedDivider).padding(.leading, 48)
    }

    // MARK: - Derived

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emailLooksValid: Bool {
        let e = trimmedEmail
        guard let at = e.firstIndex(of: "@") else { return false }
        return e.count >= 5 && e[e.index(after: at)...].contains(".") && !e.contains(" ")
    }

    private var lastSyncedText: String {
        if status.phase == .syncing { return "Syncing now" }
        return status.lastSyncedAt.map(relative) ?? "Not yet"
    }

    private func relative(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 60 { return "Just now" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func resendWait(now: Date) -> Int {
        guard let resendAvailableAt else { return 0 }
        return max(0, Int(resendAvailableAt.timeIntervalSince(now).rounded(.up)))
    }

    // MARK: - Actions

    private func send() async {
        guard emailLooksValid, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await OwnerSupabaseClient.shared.sendEmailCode(to: trimmedEmail)
            step = .code
            resendAvailableAt = Date().addingTimeInterval(60)
            setNote("Check \(trimmedEmail) for a code. It can take a minute.", error: false)
            focus = .code
        } catch let error as OwnerSyncError {
            setNote(error.ownerMessage, error: true)
        } catch {
            setNote("Couldn't send the code.", error: true)
        }
    }

    private func verify() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await OwnerSupabaseClient.shared.verifyEmailCode(email: trimmedEmail, token: trimmedCode)
            code = ""
            focus = nil
            RedMedHaptics.success()
            setNote(nil)
            await ProfileCloudSync.didSignIn(into: profile)
        } catch OwnerSyncError.http(let httpStatus) where (400..<500).contains(httpStatus) {
            setNote("That code didn't work. Check it, or tap Resend.", error: true)
        } catch let error as OwnerSyncError {
            setNote(error.ownerMessage, error: true)
        } catch {
            setNote("That code didn't verify.", error: true)
        }
    }

    private func signOut() async {
        busy = true
        defer { busy = false }
        await ProfileCloudSync.signOut()
        step = .email
        setNote("Signed out on this iPhone. RedMed and the band are unchanged.", error: false)
    }

    private func signOutAll() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await ProfileCloudSync.signOutAllDevices()
            step = .email
            setNote("Signed out on every device. RedMed and the band are unchanged.", error: false)
        } catch let error as OwnerSyncError {
            setNote("Couldn't sign out other devices. \(error.ownerMessage)", error: true)
        } catch {
            setNote("Couldn't sign out other devices. Try again.", error: true)
        }
    }

    private func deleteAccount() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await ProfileCloudSync.deleteAccount()
            step = .email
            email = ""
            RedMedHaptics.success()
            setNote("Account deleted. RedMed on this iPhone and your band are unchanged.", error: false)
        } catch let error as OwnerSyncError {
            setNote("Account not deleted. \(error.ownerMessage)", error: true)
        } catch {
            setNote("Account not deleted. Try again.", error: true)
        }
    }

    private func setNote(_ text: String?, error: Bool = false) {
        note = text
        noteIsError = error
    }
}
