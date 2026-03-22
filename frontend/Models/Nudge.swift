import FirebaseFirestore

struct Nudge: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var contact_name: String
    var phone_or_email: String
    var days_since_contact: Int
    var total_messages: Int
    var drift_score: Double
    var talking_points: [String]
    var conversation_starters: [String]
    var last_message_preview: String
    var dismissed: Bool
}
