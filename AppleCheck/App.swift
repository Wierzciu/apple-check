import SwiftUI
import BackgroundTasks

@main
struct AppleCheckApp: App {
    // Kontroler persystencji (Core Data)
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

// AppDelegate do rejestracji BGTask i powiadomień
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Rejestracja zadań w tle
        BackgroundScheduler.shared.registerTasks()
        // Rejestracja powiadomień lokalnych
        NotificationManager.shared.requestAuthorization()
        return true
    }
}

