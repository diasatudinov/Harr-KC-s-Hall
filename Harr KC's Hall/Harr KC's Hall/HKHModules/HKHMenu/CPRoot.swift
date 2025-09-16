//
//  CPRoot.swift
//  Harr KC's Hall
//
//


import SwiftUI

struct CPRoot: View {
    
    @StateObject private var state = AppStateManager()
    @StateObject private var fcmManager = FCMManager.shared
        
    var body: some View {
        Group {
            switch state.appState {
            case .fetch:
                HKHLoaderView()
                
            case .supp:
                if let url = state.webManager.targetURL {
                    WebViewManager(url: url, webManager: state.webManager)
                } else if let fcmToken = fcmManager.fcmToken {
                    WebViewManager(
                        url: NetworkManager.getInitialURL(fcmToken: fcmToken),
                        webManager: state.webManager
                    )
                } else {
                    WebViewManager(
                        url: NetworkManager.initialURL,
                        webManager: state.webManager
                    )
                }
                
            case .final:
                HKHMenuView()
                    .onAppear {
                        AppDelegate.orientationLock = .landscape
                        setOrientation(.landscapeRight)
                    }
                    .onDisappear {
                        AppDelegate.orientationLock = .all
                    }
            }
        }
        .onAppear {
            state.stateCheck()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("didReceiveRemoteNotification"))) { notification in
            handlePushNotification(notification)
        }
    }
    
    private func handlePushNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        print("🔔 Push notification received: \(userInfo)")
        
        // Здесь можно добавить логику обработки пуш-уведомлений
        // Например, навигация к определенному экрану или обновление данных
    }
    
    private func setOrientation(_ orientation: UIInterfaceOrientation) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let selector = NSSelectorFromString("setInterfaceOrientation:")
            if let responder = windowScene.value(forKey: "keyWindow") as? UIResponder, responder.responds(to: selector) {
                responder.perform(selector, with: orientation.rawValue)
            }
        }
    }
}

#Preview {
    CPRoot()
}
