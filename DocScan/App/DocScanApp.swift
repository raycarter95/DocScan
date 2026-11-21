import SwiftUI
import GoogleSignIn

@main
struct DocScanApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var google = GoogleAuth()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(settings)
                .environmentObject(google)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await google.restore()
                }
        }
    }
}
