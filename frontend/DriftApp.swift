import SwiftUI
import FirebaseCore

@main
struct DriftApp: App {
    init() {
        FirebaseApp.configure()
        NotificationManager.shared.requestPermission()
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "Sparkling Valentine", size: 34) ?? UIFont.boldSystemFont(ofSize: 34)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }

    var body: some Scene {
        WindowGroup {
            NudgeListView()
        }
    }
}
