import SwiftUI

struct NudgeListView: View {
    @StateObject private var viewModel: NudgeViewModel
    @State private var selectedNudge: Nudge? = nil

    init(viewModel: NudgeViewModel = NudgeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.nudges.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No nudges right now")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("You're keeping up with everyone!")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12, pinnedViews: []) {
                            Text("Drift")
                                .font(.custom("Sparkling Valentine", size: 40))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            Button("Test Notification (Jake)") {
                                if let nudge = viewModel.nudges.first(where: { $0.contact_name == "Jake" }) {
                                    NotificationManager.shared.scheduleNudge(for: nudge)
                                }
                            }
                            .foregroundStyle(.gray)
                            .font(.caption)
                            ForEach(viewModel.nudges.sorted { $0.drift_score > $1.drift_score }) { nudge in
                                NavigationLink(destination: NudgeDetailView(nudge: nudge, viewModel: viewModel)) {
                                    NudgeCardView(nudge: nudge)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color.black)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $selectedNudge) { nudge in
                NudgeDetailView(nudge: nudge, viewModel: viewModel)
            }
        }
        .background(Color.black)
        .onReceive(NotificationCenter.default.publisher(for: .didTapNudgeNotification)) { note in
            guard let nudgeId = note.object as? String else { return }
            selectedNudge = viewModel.nudges.first { $0.id == nudgeId }
        }
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear { viewModel.stopListening() }
    }
}

#Preview {
    let vm = NudgeViewModel()
    vm.nudges = [
        Nudge(
            id: "1",
            contact_name: "Jake",
            phone_or_email: "+11234567890",
            days_since_contact: 45,
            total_messages: 200,
            drift_score: 6.2,
            talking_points: ["How's the new job going?", "We should grab coffee soon"],
            last_message_preview: "Yeah let's hang soon",
            dismissed: false
        ),
        Nudge(
            id: "2",
            contact_name: "Sarah",
            phone_or_email: "+10987654321",
            days_since_contact: 30,
            total_messages: 150,
            drift_score: 4.8,
            talking_points: ["Saw that movie you recommended!", "How's the family?"],
            last_message_preview: "Miss you!",
            dismissed: false
        ),
        Nudge(
            id: "3",
            contact_name: "William",
            phone_or_email: "+16096423762",
            days_since_contact: 15,
            total_messages: 32323,
            drift_score: 9.8,
            talking_points: ["Saw that movie you recommended!", "How's the family?"],
            last_message_preview: "Miss you!",
            dismissed: false
        )
    ]
    return NudgeListView(viewModel: vm)
}

