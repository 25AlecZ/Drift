import SwiftUI

struct NudgeListView: View {
    @StateObject private var viewModel: NudgeViewModel
    @State private var selectedNudge: Nudge? = nil
    @State private var highlightedTalkingPointIndex: Int? = nil
    @State private var showNotifications = false
    @State private var pendingNotificationIds: Set<String> = []
    @State private var snoozedNudgeIds: Set<String> = []

    private var pendingNudges: [Nudge] {
        viewModel.nudges
            .filter { pendingNotificationIds.contains($0.id ?? "") }
            .sorted { $0.drift_score > $1.drift_score }
    }

    private var snoozedNudges: [Nudge] {
        viewModel.nudges
            .filter { snoozedNudgeIds.contains($0.id ?? "") }
            .sorted { $0.drift_score > $1.drift_score }
    }

    private var totalNotificationCount: Int { pendingNudges.count + snoozedNudges.count }

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
                            .font(.system(size: 36, weight: .black, design: .serif))
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
                                if totalNotificationCount > 0 {
                                    Text("\(totalNotificationCount)")
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
                                .font(.custom("EBGaramond-Regular", size: 20))
                                .foregroundStyle(Color(red: 0.13, green: 0.15, blue: 0.22))
                            Text("You're keeping up with everyone!")
                                .font(.custom("EBGaramond-Regular", size: 15))
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
            NudgeDetailView(nudge: nudge, viewModel: viewModel, highlightedTalkingPointIndex: highlightedTalkingPointIndex)
                .onDisappear { highlightedTalkingPointIndex = nil }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationListSheet(
                pendingNudges: pendingNudges,
                snoozedNudges: snoozedNudges,
                onSelectPending: { nudge in
                    pendingNotificationIds.remove(nudge.id ?? "")
                    showNotifications = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectedNudge = nudge
                    }
                },
                onSelectSnoozed: { nudge in
                    snoozedNudgeIds.remove(nudge.id ?? "")
                    showNotifications = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectedNudge = nudge
                    }
                }
            )
        }
        // Notification delivered → add to bell list
        .onReceive(NotificationCenter.default.publisher(for: .didDeliverNudgeNotification)) { note in
            guard let nudgeId = note.object as? String, !nudgeId.isEmpty else { return }
            pendingNotificationIds.insert(nudgeId)
        }
        // Notification banner tapped → remove from bell list, open detail
        .onReceive(NotificationCenter.default.publisher(for: .didTapNudgeNotification)) { note in
            guard let info = note.object as? [String: Any],
                  let nudgeId = info["nudgeId"] as? String else { return }
            let index = info["talkingPointIndex"] as? Int
            pendingNotificationIds.remove(nudgeId)
            highlightedTalkingPointIndex = index
            selectedNudge = viewModel.nudges.first { $0.id == nudgeId }
        }
        // Snooze tapped → move from pending to snoozed
        .onReceive(NotificationCenter.default.publisher(for: .didSnoozeNudge)) { note in
            guard let nudgeId = note.object as? String else { return }
            pendingNotificationIds.remove(nudgeId)
            snoozedNudgeIds.insert(nudgeId)
        }
        .onAppear {
            viewModel.startListening()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                let jadenNudge = Nudge(
                    id: "jaden-demo",
                    contact_name: "Jaden",
                    phone_or_email: "",
                    days_since_contact: 22,
                    total_messages: 180,
                    drift_score: 4.8,
                    talking_points: ["That new hike you wanted to check out", "Dinner spot"],
                    conversation_starters: ["yo you ever end up doing that hike?", "dude we need to find a new dinner spot fr"],
                    subtitle: "Time to reconnect after 22 days?",
                    last_message_preview: "",
                    dismissed: false
                )
                let graceNudge = Nudge(
                    id: "grace-demo",
                    contact_name: "Grace",
                    phone_or_email: "",
                    days_since_contact: 31,
                    total_messages: 210,
                    drift_score: 5.4,
                    talking_points: ["Word Hunt rivalry"],
                    conversation_starters: ["ok we need to restart the word hunt rivalry i've been practicing lol"],
                    subtitle: "It's been 31 days — worth a message?",
                    last_message_preview: "",
                    dismissed: false
                )
                let jamesNudge = Nudge(
                    id: "james-sullivan-demo",
                    contact_name: "James Sullivan",
                    phone_or_email: "",
                    days_since_contact: 18,
                    total_messages: 240,
                    drift_score: 5.1,
                    talking_points: ["March Madness bracket"],
                    conversation_starters: ["bro your bracket is cooked lmao, still watching?"],
                    subtitle: "Time to reconnect after 18 days?",
                    last_message_preview: "",
                    dismissed: false
                )
                NotificationManager.shared.scheduleNudge(for: jadenNudge, delay: 8)
                NotificationManager.shared.scheduleNudge(for: graceNudge, delay: 16)
                NotificationManager.shared.scheduleNudge(for: jamesNudge, delay: 24)
                NotificationManager.shared.scheduleWeeklyNudges(for: viewModel.nudges)
            }
        }
        .onDisappear { viewModel.stopListening() }
    }
}

private struct NotificationListSheet: View {
    let pendingNudges: [Nudge]
    let snoozedNudges: [Nudge]
    let onSelectPending: (Nudge) -> Void
    let onSelectSnoozed: (Nudge) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notifications")
                    .font(.custom("EBGaramond-Regular", size: 17).bold())
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

            if pendingNudges.isEmpty && snoozedNudges.isEmpty {
                Spacer()
                Text("No notifications")
                    .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        // Recent Nudges section
                        if !pendingNudges.isEmpty {
                            Section {
                                ForEach(pendingNudges) { nudge in
                                    nudgeRow(nudge: nudge) { onSelectPending(nudge) }
                                }
                            } header: {
                                sectionHeader("Recent Nudges")
                            }
                        }

                        // Snoozed section
                        if !snoozedNudges.isEmpty {
                            Section {
                                ForEach(snoozedNudges) { nudge in
                                    nudgeRow(nudge: nudge) { onSelectSnoozed(nudge) }
                                }
                            } header: {
                                sectionHeader("Snoozed")
                            }
                        }
                    }
                }
            }
        }
        .background(Color.white)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("EBGaramond-Regular", size: 13).bold())
            .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.white)
    }

    private func nudgeRow(nudge: Nudge, action: @escaping () -> Void) -> some View {
        Group {
            Button(action: action) {
                HStack(spacing: 14) {
                    AvatarView(name: nudge.contact_name, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stay in touch with \(nudge.contact_name)")
                            .font(.custom("EBGaramond-Regular", size: 15).bold())
                            .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                            .multilineTextAlignment(.leading)
                        Text("It's been \(nudge.days_since_contact) days")
                            .font(.custom("EBGaramond-Regular", size: 13))
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
            subtitle: "Reach out? It's been 67 days.",
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
            subtitle: "43 days of silence.",
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
            subtitle: "Still thinking about them? 28 days.",
            last_message_preview: "Sounds good!",
            dismissed: false
        )
    ]
    return NudgeListView(viewModel: vm)
}
