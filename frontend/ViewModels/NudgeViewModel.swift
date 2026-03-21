import Foundation
import FirebaseCore
import FirebaseFirestore

class NudgeViewModel: ObservableObject {
    @Published var nudges: [Nudge] = []

    private var listener: ListenerRegistration?
    private var db: Firestore? { FirebaseApp.app() != nil ? Firestore.firestore() : nil }

    func startListening() {
        guard let db else { return }
        listener = db.collection("nudges")
            .whereField("dismissed", isEqualTo: false)
            .order(by: "drift_score", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self.nudges = documents.compactMap { try? $0.data(as: Nudge.self) }
            }
    }

    func stopListening() {
        listener?.remove()
    }

    func dismiss(nudge: Nudge) {
        nudges.removeAll { $0.id == nudge.id }
        guard let id = nudge.id else { return }
        db?.collection("nudges").document(id).updateData(["dismissed": true])
    }

    func keep(nudge: Nudge) {
        // Nudge is already not dismissed; this is a no-op that just navigates back.
        // Could be extended to set a "snoozed_until" field in the future.
    }

    func sendMessage(to nudge: Nudge) {
        let raw = nudge.phone_or_email
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        guard let url = URL(string: "sms:\(raw)"), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
