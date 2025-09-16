import UIKit
import SwiftUI
@preconcurrency import WebKit

class NetworkManager: ObservableObject {
    
    // MARK: - CHANGE URL HERE
    static let BASE_URL = "https://zabkagrand.top/play"
    // MARK: - CHANGE URL HERE
    
    @Published private(set) var targetURL: URL?
    private let storage: UserDefaults
    private var didSaveURL = false
    private let requestTimeout: TimeInterval = 10.0
    
    init(storage: UserDefaults = .standard) {
        self.storage = storage
        loadProvenURL()
    }
    
    static func isInitialURL(_ url: URL) -> Bool {
        guard let baseURL = URL(string: BASE_URL),
              url.host == baseURL.host,
              url.path == baseURL.path else {
            return false
        }
        return true
    }
    
    /// Начальный URL для проверки при запуске приложения с FCM токеном
    static func getInitialURL(fcmToken: String) -> URL {
        guard var components = URLComponents(string: BASE_URL) else {
            fatalError("Invalid BASE_URL: \(BASE_URL)")
        }
        
        // Добавляем FCM токен как параметр
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "fcm", value: fcmToken))
        components.queryItems = queryItems
        
        guard let url = components.url else {
            fatalError("Failed to create URL with FCM token")
        }
        
        return url
    }
    
    /// Базовый URL без FCM токена (для обратной совместимости)
    static var initialURL: URL {
        guard let url = URL(string: BASE_URL) else {
            fatalError("Invalid BASE_URL: \(BASE_URL)")
        }
        return url
    }
    
    func checkURL(_ url: URL) {
        if didSaveURL {
            return
        }
        
        guard !isInvalidURL(url) else {
            return
        }
        
        storage.set(url.absoluteString, forKey: "savedurlZZ")
        targetURL = url
        didSaveURL = true
    }
    
    private func loadProvenURL() {
        if let urlString = storage.string(forKey: "savedurlZZ") {
            if let url = URL(string: urlString) {
                targetURL = url
                didSaveURL = true
            } else {
                print("Error: load - \(urlString)")
            }
        }
    }
    
    private func isInvalidURL(_ url: URL) -> Bool {
        let invalidURLs = ["about:blank", "about:srcdoc"]
        
        if invalidURLs.contains(url.absoluteString) {
            return true
        }
        
        if url.host?.contains("google.com") == true {
            return true
        }
        
        return false
    }
    
    func checkInitialURL() async throws -> Bool {
        // Ждем получения FCM токена
        let fcmToken = await FCMManager.shared.waitForToken()
        let initialURL = Self.getInitialURL(fcmToken: fcmToken)
        
        print("\n🌐 Request: GET \(initialURL)")
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout
        let session = URLSession(configuration: configuration)
        
        var request = URLRequest(url: initialURL)
        request.setValue(getUAgent(forWebView: false), forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = requestTimeout
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return false
            }
            
            print("📡 Response: [Status: \(httpResponse.statusCode)] \(initialURL)")
            
            if (400...599).contains(httpResponse.statusCode) {
                print("❌ Server error: \(httpResponse.statusCode)")
                return false
            }
            
            print("✅ FCM token sent successfully: \(fcmToken)")
            return true
            
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getUAgent(forWebView: Bool = false) -> String {
        if forWebView {
            let version = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
            let agent = "Mozilla/5.0 (iPhone; CPU iPhone OS \(version) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
            return agent
        } else {
            let agent = "TestRequest/1.0 CFNetwork/1410.0.3 Darwin/22.4.0"
            return agent
        }
    }
}

struct WebViewManager: UIViewRepresentable {
    let url: URL
    let webManager: NetworkManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.bounces = true
        webView.customUserAgent = webManager.getUAgent(forWebView: true)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewManager
        
        init(_ parent: WebViewManager) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let finalURL = webView.url else {
                return
            }
            
            if !NetworkManager.isInitialURL(finalURL) {
                parent.webManager.checkURL(finalURL)
            } else {
                print("Still on initial URL")
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Provisional navigation failed: \(error.localizedDescription)")
        }
    }
}