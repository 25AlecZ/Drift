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
            SplashView()
        }
    }
}

struct SplashView: View {
    @State private var isActive = false
    @State private var opacity = 1.0

    private let beige = Color(red: 0.87, green: 0.85, blue: 0.80)

    var body: some View {
        if isActive {
            NudgeListView()
        } else {
            ZStack {
                beige.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image("DriftLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                    Text("DRIFT")
                        .font(.system(size: 48, weight: .black, design: .serif))
                        .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                }
                .opacity(opacity)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        opacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        isActive = true
                    }
                }
            }
        }
    }
}
