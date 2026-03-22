import Foundation

private let demoNamesList = [
    "Alex Chen", "Jordan Lee", "Sam Rivera", "Morgan Kim",
    "Casey Park", "Tyler Wong", "Jamie Patel", "Riley Martinez",
    "Drew Nguyen", "Avery Singh"
]

class DemoNameMapper {
    static let shared = DemoNameMapper()
    private var mapping: [String: String] = [:]

    /// Call this once when nudges are loaded. Assigns unique names sorted by ID.
    func assign(nudges: [Nudge]) {
        let sorted = nudges.sorted { ($0.id ?? "") < ($1.id ?? "") }
        mapping = [:]
        for (i, nudge) in sorted.enumerated() {
            guard let id = nudge.id else { continue }
            mapping[id] = demoNamesList[i % demoNamesList.count]
        }
    }

    func name(for nudge: Nudge) -> String {
        nudge.id.flatMap { mapping[$0] } ?? demoNamesList[0]
    }
}

func demoName(for nudge: Nudge) -> String {
    DemoNameMapper.shared.name(for: nudge)
}
