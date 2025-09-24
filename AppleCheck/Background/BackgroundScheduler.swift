import Foundation
import BackgroundTasks

final class BackgroundScheduler {
    static let shared = BackgroundScheduler()
    private init() {}

    private let taskId = "com.example.AppleCheck.refresh"

    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            self.handle(task as! BGAppRefreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        let minutes = SettingsViewModel().refreshIntervalMinutes
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(minutes * 60))
        do { try BGTaskScheduler.shared.submit(request) } catch {
            Logger.shared.log("Błąd submit BGTask: \(error)")
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        scheduleAppRefresh()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let op = RefreshOperation()
        task.expirationHandler = { queue.cancelAllOperations() }
        op.completionBlock = { task.setTaskCompleted(success: !op.isCancelled) }
        queue.addOperation(op)
    }
}

private final class RefreshOperation: Operation, @unchecked Sendable {
    override func main() {
        let group = DispatchGroup()
        group.enter()
        Task {
            // Utworzenie MainViewModel na głównym aktorze i jednorazowe odświeżenie
            let task: Task<Void, Never> = await MainActor.run {
                let vm = MainViewModel()
                return Task { await vm.refreshOnce() }
            }
            await task.value
            group.leave()
        }
        group.wait()
    }
}

