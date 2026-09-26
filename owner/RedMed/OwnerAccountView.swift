import SwiftUI

/// Email one-time code for the wearer account. Hidden unless
/// `AppConfig.profileSyncEnabled` is true. Sign in with Apple waits on the
/// paid team. The session JWT stays in Keychain. The band is not rewritten.
struct OwnerAccountView: View {
    @EnvironmentObject private var profile: ProfileData
    @State private var email = ""
    @State private var code = ""
    @State private var status = ""
    @State private var busy = false
    @State private var signedIn = OwnerSupabaseClient.shared.currentSession() != nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account sync")
                .font(.system(size: 20, weight: .semibold))
            Text("Saves the wearer copy to your sign-in so another iPhone can load it. The tap page does not look it up. Writing the band is still a separate step.")
                .font(.system(size: 14))
                .foregroundColor(.redmedMuted)
            if signedIn {
                Text("Signed in")
                    .font(.system(size: 15, weight: .medium))
                Button("Sign out") {
                    OwnerSupabaseClient.shared.signOut()
                    signedIn = false
                    status = "Signed out on this iPhone. The band is unchanged."
                }
            } else {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(busy ? "Sending…" : "Email me a code") {
                    Task { await send() }
                }
                .disabled(busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                TextField("Code", text: $code)
                    .keyboardType(.numberPad)
                Button(busy ? "Checking…" : "Verify code") {
                    Task { await verify() }
                }
                .disabled(busy || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if profile.accountNewerThanBand {
                Text("The account copy is newer than the last verified band write. The band does not change until you write it.")
                    .font(.system(size: 13, weight: .medium))
            }
            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 13))
                    .foregroundColor(.redmedMuted)
            }
        }
        .padding(16)
    }

    private func send() async {
        busy = true
        defer { busy = false }
        do {
            try await OwnerSupabaseClient.shared.sendEmailCode(to: email.trimmingCharacters(in: .whitespacesAndNewlines))
            status = "Check that email for a code."
        } catch {
            status = "Could not send the code."
        }
    }

    private func verify() async {
        busy = true
        defer { busy = false }
        do {
            try await OwnerSupabaseClient.shared.verifyEmailCode(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                token: code.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            signedIn = true
            status = "Signed in."
            await ProfileCloudSync.pullIfNeeded(into: profile)
        } catch {
            status = "That code did not verify."
        }
    }
}
