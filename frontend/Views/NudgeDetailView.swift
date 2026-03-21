import SwiftUI

struct NudgeDetailView: View {
    let nudge: Nudge
    @ObservedObject var viewModel: NudgeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nudge.contact_name)
                            .font(.title.bold())
                        Text("\(nudge.days_since_contact) days since last contact")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(nudge.total_messages) messages total")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    DriftScoreBadge(score: nudge.drift_score)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // Last message preview
                if !nudge.last_message_preview.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Last message", systemImage: "bubble.left")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("\"\(nudge.last_message_preview)\"")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }

                // Talking points
                if !nudge.talking_points.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Conversation starters", systemImage: "sparkles")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        ForEach(nudge.talking_points, id: \.self) { point in
                            TalkingPointRow(text: point, phoneOrEmail: nudge.phone_or_email)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        viewModel.sendMessage(to: nudge)
                    } label: {
                        Label("Send Message", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .font(.headline)
                    }

                    HStack(spacing: 12) {
                        Button {
                            viewModel.keep(nudge: nudge)
                            dismiss()
                        } label: {
                            Label("Keep", systemImage: "bookmark")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.regularMaterial)
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(role: .destructive) {
                            viewModel.dismiss(nudge: nudge)
                            dismiss()
                        } label: {
                            Label("Remove", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.regularMaterial)
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(nudge.contact_name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TalkingPointRow: View {
    let text: String
    let phoneOrEmail: String

    var body: some View {
        Button {
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let raw = phoneOrEmail
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()
            if let url = URL(string: "sms:\(raw)&body=\(encoded)") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.message")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
