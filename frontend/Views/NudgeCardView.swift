import SwiftUI

struct NudgeCardView: View {
    let nudge: Nudge

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nudge.contact_name)
                        .font(.headline)
                    Text("\(nudge.days_since_contact) days since last contact")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DriftScoreBadge(score: nudge.drift_score)
            }

            if !nudge.last_message_preview.isEmpty {
                Text("\"\(nudge.last_message_preview)\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(urgencyColor(nudge.drift_score).opacity(0.3), lineWidth: 1)
        )
    }

    private func urgencyColor(_ score: Double) -> Color {
        switch score {
        case 7...: return .red
        case 4...: return .orange
        default:   return .yellow
        }
    }
}

struct DriftScoreBadge: View {
    let score: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f", score))
                .font(.title2.bold())
                .foregroundStyle(scoreColor)
        }
    }

    private var scoreColor: Color {
        switch score {
        case 7...: return .red
        case 4...: return .orange
        default:   return .yellow
        }
    }
}
