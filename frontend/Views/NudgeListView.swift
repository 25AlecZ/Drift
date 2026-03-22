import SwiftUI

struct NudgeListView: View {
    @StateObject private var viewModel: NudgeViewModel
    @State private var selectedNudge: Nudge? = nil
    @State private var showNotifications = false
    @State private var pendingNotificationIds: Set<String> = []

    private var pendingNudges: [Nudge] {
        viewModel.nudges
            .filter { pendingNotificationIds.contains($0.id ?? "") }
            .sorted { $0.drift_score > $1.drift_score }
    }

    init(viewModel: NudgeViewModel = NudgeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private let beige = Color(red: 0.87, green: 0.85, blue: 0.80)

    var body: some View {
        NavigationStack {
            ZStack {
                beige.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Image("DriftLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                        Text("DRIFT")
                            .font(.custom("EBGaramond", size: 36).bold())
                            .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                        Spacer()
                        Button {
                            showNotifications = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                                    .padding(12)
                                    .background(Color.white, in: Circle())
                                if !pendingNudges.isEmpty {
                                    Text("\(pendingNudges.count)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Color.red, in: Circle())
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    if viewModel.nudges.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color(red: 0.13, green: 0.15, blue: 0.22))
                            Text("No nudges right now")
                                .font(.custom("EBGaramond", size: 20))
                                .foregroundStyle(Color(red: 0.13, green: 0.15, blue: 0.22))
                            Text("You're keeping up with everyone!")
                                .font(.custom("EBGaramond", size: 15))
                                .foregroundStyle(Color(red: 0.13, green: 0.15, blue: 0.22).opacity(0.6))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.nudges.sorted { $0.drift_score > $1.drift_score }) { nudge in
                                    Button {
                                        selectedNudge = nudge
                                    } label: {
                                        NudgeCardView(nudge: nudge)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedNudge) { nudge in
            NudgeDetailView(nudge: nudge, viewModel: viewModel)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationListSheet(nudges: pendingNudges) { nudge in
                pendingNotificationIds.remove(nudge.id ?? "")
                showNotifications = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    selectedNudge = nudge
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didTapNudgeNotification)) { note in
            guard let nudgeId = note.object as? String else { return }
            pendingNotificationIds.insert(nudgeId)
            selectedNudge = viewModel.nudges.first { $0.id == nudgeId }
        }
        .onAppear {
            viewModel.startListening()
            // Demo: fire a single test notification 8 seconds after launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if let nudge = viewModel.nudges.randomElement() {
                    NotificationManager.shared.scheduleNudge(for: nudge, delay: 8)
                }
                // Schedule weekly nudges spread across the next 7 days
                NotificationManager.shared.scheduleWeeklyNudges(for: viewModel.nudges)
            }
        }
        .onDisappear { viewModel.stopListening() }
    }
}

private struct NotificationListSheet: View {
    let nudges: [Nudge]
    let onSelect: (Nudge) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Nudges")
                    .font(.custom("EBGaramond", size: 17).bold())
                    .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                        .padding(8)
                        .background(Color(red: 0.90, green: 0.90, blue: 0.92), in: Circle())
                }
            }
            .padding()

            Divider()

            if nudges.isEmpty {
                Spacer()
                Text("No recent nudges")
                    .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(nudges) { nudge in
                            Button {
                                onSelect(nudge)
                            } label: {
                                HStack(spacing: 14) {
                                    AvatarView(name: nudge.contact_name, size: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Stay in touch with \(nudge.contact_name)")
                                            .font(.custom("EBGaramond", size: 15).bold())
                                            .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                                            .multilineTextAlignment(.leading)
                                        Text("It's been \(nudge.days_since_contact) days")
                                            .font(.custom("EBGaramond", size: 13))
                                            .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Color(red: 0.7, green: 0.7, blue: 0.7))
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 72)
                        }
                    }
                }
            }
        }
        .background(Color.white)
    }
}

#Preview {
    let vm = NudgeViewModel()
    vm.nudges = [
        Nudge(
            id: "1",
            contact_name: "Alex Bennett",
            phone_or_email: "+11234567890",
            days_since_contact: 67,
            total_messages: 200,
            drift_score: 6.2,
            talking_points: ["New job update", "That book you were reading", "Coffee plans"],
            conversation_starters: ["yo how's the new job going??", "did you ever finish that book lol", "dude we need to grab coffee soon fr"],
            last_message_preview: "Yeah let's hang soon",
            dismissed: false
        ),
        Nudge(
            id: "2",
            contact_name: "Casey Davis",
            phone_or_email: "+10987654321",
            days_since_contact: 43,
            total_messages: 150,
            drift_score: 4.8,
            talking_points: ["That movie recommendation", "Family update"],
            conversation_starters: ["ok i finally watched that movie you told me about lmao", "how's the fam doing?"],
            last_message_preview: "Miss you!",
            dismissed: false
        ),
        Nudge(
            id: "3",
            contact_name: "Eli Foster",
            phone_or_email: "+16096423762",
            days_since_contact: 28,
            total_messages: 300,
            drift_score: 3.5,
            talking_points: ["New apartment", "Morning runs"],
            conversation_starters: ["how's the new place treating you?", "you still doing those morning runs or did that die lol"],
            last_message_preview: "Sounds good!",
            dismissed: false
        )
    ]
    return NudgeListView(viewModel: vm)
}
