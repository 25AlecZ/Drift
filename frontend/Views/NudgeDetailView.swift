import SwiftUI
import UserNotifications

struct NudgeDetailView: View {
    let nudge: Nudge
    @ObservedObject var viewModel: NudgeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // X button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                        .padding(10)
                        .background(Color(red: 0.90, green: 0.90, blue: 0.92), in: Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 24) {
                    // Avatar + name + subtitle
                    VStack(spacing: 12) {
                        AvatarView(name: nudge.contact_name, size: 80)
                        Text(nudge.contact_name)
                            .font(.title.bold())
                            .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                        Text("It's been \(nudge.days_since_contact) days")
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                    }
                    .padding(.top, 8)

                    // Talking points
                    if !nudge.talking_points.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Talking points")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                            ForEach(Array(nudge.talking_points.enumerated()), id: \.offset) { index, point in
                                Button {
                                    let message = index < nudge.conversation_starters.count
                                        ? nudge.conversation_starters[index] : point
                                    let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                    let raw = nudge.phone_or_email
                                        .components(separatedBy: CharacterSet.decimalDigits.inverted)
                                        .joined()
                                    if let url = URL(string: "sms:\(raw)&body=\(encoded)") {
                                        UIApplication.shared.open(url)
                                    }
                                    dismiss()
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                                        Text(point)
                                            .font(.subheadline)
                                            .foregroundStyle(Color(red: 0.2, green: 0.22, blue: 0.28))
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "arrow.up.message")
                                            .font(.caption)
                                            .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 0.9))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.97), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Stay in touch?
                    VStack(spacing: 16) {
                        Text("Stay in touch?")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))

                        HStack(spacing: 12) {
                            Button {
                                viewModel.sendMessage(to: nudge)
                                dismiss()
                            } label: {
                                Text("Yes")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(red: 0.13, green: 0.15, blue: 0.22))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button {
                                viewModel.dismiss(nudge: nudge)
                                dismiss()
                            } label: {
                                Text("No")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(red: 0.90, green: 0.90, blue: 0.92))
                                    .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        Button {
                            UNUserNotificationCenter.current().removePendingNotificationRequests(
                                withIdentifiers: ["weekly-\(nudge.id ?? "")"]
                            )
                            NotificationManager.shared.scheduleNudge(for: nudge, delay: 86400)
                            dismiss()
                        } label: {
                            Label("Snooze", systemImage: "moon.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                                .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            viewModel.sendMessage(to: nudge)
                            dismiss()
                        } label: {
                            Text("Go to chat →")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color(red: 0.78, green: 0.78, blue: 0.80), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .background(Color.white)
    }
}

#Preview {
    let vm = NudgeViewModel()
    let nudge = Nudge(
        id: "1",
        contact_name: "Alex Bennett",
        phone_or_email: "+11234567890",
        days_since_contact: 67,
        total_messages: 200,
        drift_score: 6.2,
        talking_points: ["New job update", "That book you were reading", "Warriors playoff run"],
        conversation_starters: ["yo how's the new job going??", "did you ever finish that book lol", "bro are you watching the warriors rn"],
        last_message_preview: "Yeah let's hang soon",
        dismissed: false
    )
    return NudgeDetailView(nudge: nudge, viewModel: vm)
}
