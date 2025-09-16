//
//  FCMManager.swift
//  Harr KC's Hall
//
//


import FirebaseMessaging

class FCMManager: ObservableObject {
    static let shared = FCMManager()
    
    @Published private(set) var fcmToken: String?
    private var continuation: CheckedContinuation<String, Never>?
    
    private init() {}
    
    func setToken(_ token: String) {
        self.fcmToken = token
        continuation?.resume(returning: token)
        continuation = nil
    }
    
    func waitForToken() async -> String {
        // Если токен уже есть - возвращаем его
        if let existingToken = fcmToken {
            return existingToken
        }
        
        // Если нет - ждем получения
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}
