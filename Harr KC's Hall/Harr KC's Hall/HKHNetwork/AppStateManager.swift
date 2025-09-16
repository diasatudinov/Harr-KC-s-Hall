//
//  AppStateManager.swift
//  Harr KC's Hall
//
//


import Foundation

@MainActor
final class AppStateManager: ObservableObject {
    
    enum AppState {
        case fetch
        case supp
        case final
    }
    
    @Published private(set) var appState: AppState = .fetch
    let webManager: NetworkManager
    
    private var timeoutTask: Task<Void, Never>?
    private let maxLoadingTime: TimeInterval = 15.0
    
    init(webManager: NetworkManager = NetworkManager()) {
        self.webManager = webManager
    }
    
    func stateCheck() {
        timeoutTask?.cancel()
        
        Task { @MainActor in
            do {
                // Если уже есть сохраненный URL - используем его
                if webManager.targetURL != nil {
                    updateState(.supp)
                    return
                }
                
                // Проверяем начальный URL с FCM токеном
                // Новая логика автоматически отправляет только новые токены
                let shouldShowWebView = try await webManager.checkInitialURL()
                
                if shouldShowWebView {
                    updateState(.supp)
                } else {
                    updateState(.final)
                }
                
            } catch {
                print("❌ StateCheck error: \(error.localizedDescription)")
                updateState(.final)
            }
        }
        
        startTimeoutTask()
    }
    
    private func updateState(_ newState: AppState) {
        timeoutTask?.cancel()
        timeoutTask = nil
        
        appState = newState
    }
    
    private func startTimeoutTask() {
        timeoutTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(maxLoadingTime * 1_000_000_000))
                
                if self.appState == .fetch {
                    print("⏰ Timeout reached, switching to final state")
                    self.appState = .final
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    deinit {
        timeoutTask?.cancel()
    }
}
