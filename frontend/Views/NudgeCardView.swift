import SwiftUI

struct NudgeCardView: View {
    let nudge: Nudge

    var body: some View {
        HStack(spacing: 16) {
            AvatarView(name: nudge.contact_name, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(nudge.contact_name)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                Text("\(nudge.days_since_contact) days since last contact")
                    .font(.subheadline)
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
