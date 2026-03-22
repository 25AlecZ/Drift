import SwiftUI

struct NudgeCardView: View {
    let nudge: Nudge

    var body: some View {
        HStack(spacing: 16) {
            AvatarView(name: nudge.contact_name, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(nudge.contact_name)
                    .font(.custom("EBGaramond", size: 17).bold())
                    .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                Text(nudge.subtitle.isEmpty ? "\(nudge.days_since_contact) days since last contact" : nudge.subtitle)
                    .font(.custom("EBGaramond", size: 15))
                    .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color(red: 0.90, green: 0.90, blue: 0.92))
                    .frame(width: 36, height: 36)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

struct AvatarView: View {
    let name: String
    let size: CGFloat

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.13, green: 0.15, blue: 0.22))
            Text(initials)
                .foregroundStyle(.white)
                .font(.system(size: size * 0.35, weight: .bold))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    let nudge = Nudge(
        id: "1",
        contact_name: "Alex Bennett",
        phone_or_email: "+11234567890",
        days_since_contact: 67,
        total_messages: 200,
        drift_score: 6.2,
        talking_points: ["New job update", "That book you were reading"],
        conversation_starters: ["yo how's the new job going??", "did you ever finish that book lol"],
        subtitle: "Reach out? It's been 67 days.",
        last_message_preview: "Yeah let's hang soon",
        dismissed: false
    )
    return NudgeCardView(nudge: nudge)
        .padding()
        .background(Color(red: 0.87, green: 0.85, blue: 0.80))
}
