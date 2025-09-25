import SwiftUI
import BackgroundTasks

@main
struct AppleCheckApp: App {
    // Core Data container shared across the app.
    let persistenceController = PersistenceController.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(SettingsViewModel())
                .environmentObject(MainViewModel())
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                BackgroundScheduler.shared.scheduleAppRefresh()
            }
        }
    }
}

// AppDelegate handles background tasks and notifications registration.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register background refresh tasks.
        BackgroundScheduler.shared.registerTasks()
        // Request local notification permissions.
        NotificationManager.shared.requestAuthorization()
        return true
    }
}
