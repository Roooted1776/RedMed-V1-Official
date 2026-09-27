import SwiftUI
import CoreLocation
import MapKit
import MessageUI

// 911 tab, owner only: street address for the live fix, Text My Location to
// emergency contacts, one-tap contact calls, and nearest ERs.
// Nothing here reaches a RedMed server. Address lookup and ER search ask Apple
// on this phone. Texts go out only when the owner taps Send in Messages.

// MARK: - Street address

/// Reverse-geocodes the live fix so the owner can read a street address to a
/// dispatcher. Apple's geocoder on this phone, throttled so a walking fix does
/// not hammer it.
@MainActor
final class LiveAddressResolver: ObservableObject {
    @Published private(set) var address: String?

    private let geocoder = CLGeocoder()
    /// The fix `address` was resolved for.
    @Published private var lastResolved: CLLocation?
    private var lastRequestAt: Date?

    /// Re-resolve only after a real move (25 m) and at most every 15 s.
    private static let minMoveMeters: CLLocationDistance = 25
    private static let minInterval: TimeInterval = 15
    /// Past this, the address belongs to somewhere the owner has left
    /// (lookup failing offline while they keep moving). Show none rather
    /// than a wrong street next to live GPS.
    private static let maxDriftMeters: CLLocationDistance = 100

    /// Address for `fix`, or nil when the last resolved address is too far away.
    func address(near fix: CLLocation?) -> String? {
        guard let fix, let address, let lastResolved,
              lastResolved.distance(from: fix) <= Self.maxDriftMeters else { return nil }
        return address
    }

    func update(for location: CLLocation?) {
        guard let location, location.horizontalAccuracy >= 0 else { return }
        if let last = lastResolved, last.distance(from: location) < Self.minMoveMeters { return }
        if let at = lastRequestAt, Date().timeIntervalSince(at) < Self.minInterval { return }
        guard !geocoder.isGeocoding else { return }
        lastRequestAt = Date()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let formatted = placemarks?.first.flatMap(Self.format)
            Task { @MainActor in
                guard let self, let formatted else { return }
                self.lastResolved = location
                self.address = formatted
            }
        }
    }

    func stop() {
        geocoder.cancelGeocode()
    }

    /// "1 Main St, Springfield, IL 62701". Nil when Apple has no street data.
    nonisolated static func format(_ p: CLPlacemark) -> String? {
        let street = [p.subThoroughfare, p.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let region = [p.administrativeArea, p.postalCode]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let parts = [street.isEmpty ? p.name : street, p.locality, region.isEmpty ? nil : region]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - Message text

/// SMS body for Text My Location. Name + where only. Never medical fields.
enum EmergencyLocationMessage {
    static func body(
        name: String,
        location: CLLocation?,
        address: String?,
        now: Date = Date()
    ) -> String {
        let who = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = [who.isEmpty ? "EMERGENCY: I need help." : "EMERGENCY: \(who) needs help."]
        if let location, location.horizontalAccuracy >= 0 {
            if let address, !address.isEmpty {
                lines.append("Near: \(address)")
            }
            var gps = "GPS: \(GPSCard.coordinateText(location)) (±\(Int(location.horizontalAccuracy.rounded())) m)"
            if GPSCard.isStale(location, now: now) {
                let minutes = max(1, Int(now.timeIntervalSince(location.timestamp) / 60))
                gps += " — last known, \(minutes) min ago"
            }
            lines.append(gps)
            lines.append("Map: \(mapsURL(location.coordinate))")
        } else {
            lines.append("My location isn't available yet. Call me.")
        }
        let time = DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .short)
        lines.append("Sent from RedMed at \(time). If I don't answer, call \(EmergencyNumber.current).")
        return lines.joined(separator: "\n")
    }

    /// Apple Maps link any phone can open (non-iPhones get a web map).
    static func mapsURL(_ c: CLLocationCoordinate2D) -> String {
        let ll = String(format: "%.6f,%.6f", c.latitude, c.longitude)
        return "https://maps.apple.com/?ll=\(ll)&q=SOS"
    }

    /// `sms:`-safe recipients from saved contacts (digits and a leading +).
    static func recipients(_ contacts: [EmergencyContact]) -> [String] {
        var seen = Set<String>()
        return contacts.map(\.dialDigits).filter { digits in
            digits.filter(\.isNumber).count >= 3 && seen.insert(digits).inserted
        }
    }
}

// MARK: - Messages composer

/// Messages sheet prefilled with recipients + body. The owner taps Send;
/// RedMed never sends by itself.
struct MessageComposeSheet: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinish: (MessageComposeResult) -> Void

    static var canSend: Bool { MFMessageComposeViewController.canSendText() }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (MessageComposeResult) -> Void
        init(onFinish: @escaping (MessageComposeResult) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            onFinish(result)
        }
    }
}

/// Fallback when this device can't send texts (iPad without Messages, Simulator).
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Text My Location

struct ShareLocationCard: View {
    @EnvironmentObject private var profile: ProfileData
    @ObservedObject private var survivalAlarm = CrashMotionGuard.shared
    let location: CLLocation?
    let address: String?

    private enum Sheet: Identifiable {
        case messages(recipients: [String], body: String)
        case share(String)
        var id: String {
            switch self {
            case .messages: return "messages"
            case .share: return "share"
            }
        }
    }

    @State private var sheet: Sheet?
    @State private var note: String?

    private var recipients: [String] { EmergencyLocationMessage.recipients(profile.contacts) }

    private var recipientLine: String {
        let names = profile.contacts
            .filter { !$0.dialDigits.isEmpty }
            .map { $0.name.isEmpty ? $0.phone : $0.name }
        if names.isEmpty {
            return "No emergency contacts saved. You pick who gets it in Messages. Add contacts in Edit."
        }
        return "To \(ListFormatter.localizedString(byJoining: names)). You tap Send in Messages."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if survivalAlarm.isArmed {
                Text("SOS is on. Text your contacts where you are.")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedAccent)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            CompactFillButton(
                title: "Text My Location",
                systemImage: "location.fill",
                fill: survivalAlarm.isArmed ? .redmedAccent : .redmedDark
            ) {
                RedMedHaptics.medium()
                compose()
            }
            .accessibilityHint("Opens Messages with your address, GPS, and a map link for your emergency contacts. Nothing sends until you tap Send.")
            Text(note ?? recipientLine)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.redmedMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .messages(let recipients, let body):
                MessageComposeSheet(recipients: recipients, body: body) { result in
                    self.sheet = nil
                    switch result {
                    case .sent: note = "Sent. Keep your phone on you and stay reachable."
                    case .failed: note = "Messages couldn't send. Try again or call."
                    default: note = nil
                    }
                }
                .ignoresSafeArea()
            case .share(let body):
                ActivityShareSheet(items: [body])
                    .presentationDetents([.medium, .large])
            }
        }
        // Real motion-detected crash (never manual SOS) auto-opens this same
        // composer once the crash countdown ends without Stop — still one
        // tap (Send) to actually go out, iOS allows nothing less. `onAppear`
        // catches a countdown that ended before this card mounted (911 tab
        // wasn't up yet); `onChange` catches one that ends while the card is
        // already on screen. Either way
        // `consumePendingCrashAutoShare()` only returns true once.
        .onAppear { checkPendingCrashAutoShare() }
        .onChange(of: survivalAlarm.pendingCrashAutoShare) { _, pending in
            guard pending else { return }
            checkPendingCrashAutoShare()
        }
    }

    private func checkPendingCrashAutoShare() {
        guard survivalAlarm.consumePendingCrashAutoShare() else { return }
        compose()
    }

    private func compose() {
        let body = EmergencyLocationMessage.body(name: profile.name, location: location, address: address)
        note = nil
        if MessageComposeSheet.canSend {
            sheet = .messages(recipients: recipients, body: body)
        } else {
            sheet = .share(body)
        }
    }
}

// MARK: - Call a contact

/// One-tap `tel:` to each saved emergency contact. Opens the Phone app only.
struct EmergencyContactsCallCard: View {
    @EnvironmentObject private var profile: ProfileData

    private var callable: [EmergencyContact] {
        profile.contacts.filter { $0.dialDigits.filter(\.isNumber).count >= 3 }
    }

    var body: some View {
        if !callable.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Emergency Contacts")
                    .padding(.top, 12)
                    .padding(.horizontal, 10)
                ForEach(Array(callable.enumerated()), id: \.element.id) { index, contact in
                    if index > 0 {
                        Divider().overlay(Color.redmedDivider).padding(.leading, 14)
                    }
                    ContactCallRow(contact: contact)
                }
            }
            .padding(.bottom, 4)
            .redmedBox()
        }
    }
}

private struct ContactCallRow: View {
    let contact: EmergencyContact

    private var title: String { contact.name.isEmpty ? "Contact" : contact.name }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.redmedDark)
                    .lineLimit(1)
                Text(contact.detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            RowPillButton(title: "Call", systemImage: "phone.fill", filled: true) {
                RedMedHaptics.medium()
                ExternalOpen.tel(contact.dialDigits)
            }
            .accessibilityLabel("Call \(title)")
            .accessibilityHint("Opens the Phone app.")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Nearest ER

struct NearbyERCard: View {
    @StateObject private var finder = NearbyHospitalFinder()
    @State private var searched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .frame(width: 30, height: 30)
                    .background(Color.redmedAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                    .accessibilityHidden(true)
                Text("Nearest ER")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.redmedDark)
                Spacer(minLength: 6)
                if finder.isLoading {
                    ProgressView().controlSize(.small).tint(.redmedAccent)
                } else {
                    RowPillButton(title: searched ? "Refresh" : "Find", systemImage: "location.magnifyingglass", filled: false) {
                        RedMedHaptics.light()
                        searched = true
                        // Finder asks for When-In-Use itself if still undetermined.
                        finder.search()
                    }
                    .accessibilityLabel(searched ? "Refresh nearest ER" : "Find nearest ER")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if let error = finder.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            } else if searched, !finder.isLoading, finder.hospitals.isEmpty {
                Text("No hospitals found nearby. Call \(EmergencyNumber.current).")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.redmedMuted)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }

            ForEach(finder.hospitals.prefix(5)) { hospital in
                Divider().overlay(Color.redmedDivider).padding(.leading, 14)
                HospitalRow(hospital: hospital)
            }

            Text("Apple Maps search on this phone, not a trauma-center list. For an ambulance, call \(EmergencyNumber.current).")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.redmedMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.top, finder.hospitals.isEmpty ? 0 : 8)
                .padding(.bottom, 12)
        }
        .redmedBox()
    }
}

private struct HospitalRow: View {
    let hospital: NearbyHospital

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hospital.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.redmedDark)
                    .lineLimit(2)
                Text([hospital.distanceText, hospital.address].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            RowPillButton(title: "Go", systemImage: "car.fill", filled: true) {
                RedMedHaptics.medium()
                hospital.mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            }
            .accessibilityLabel("Directions to \(hospital.name)")
            if let phone = hospital.phone, !phone.isEmpty {
                RowPillButton(title: "Call", systemImage: "phone.fill", filled: false) {
                    RedMedHaptics.medium()
                    ExternalOpen.tel(phone)
                }
                .accessibilityLabel("Call \(hospital.name)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Pieces

/// Small pill used in contact / ER rows. Same chip radius as the seizure strip.
private struct RowPillButton: View {
    let title: String
    let systemImage: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(filled ? .white : .redmedDark)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(filled ? Color.redmedAccent : Color.redmedBg)
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
            .overlay(
                RoundedRectangle(cornerRadius: RedMedChrome.chipRadius)
                    .strokeBorder(Color.redmedDivider, lineWidth: filled ? 0 : 1)
            )
        }
        .buttonStyle(RedMedPressStyle(scale: 0.95, haptic: nil))
    }
}

enum ExternalOpen {
    /// System Phone app. Digits and a leading + only.
    static func tel(_ raw: String) {
        var digits = ""
        for ch in raw where ch.isNumber || (ch == "+" && digits.isEmpty) {
            digits.append(ch)
        }
        guard digits.filter(\.isNumber).count >= 3, let url = URL(string: "tel:\(digits)") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
