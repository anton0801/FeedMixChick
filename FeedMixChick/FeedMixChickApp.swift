import SwiftUI
import UIKit
import Firebase
import UserNotifications
import AppsFlyerLib
import AppTrackingTransparency

// MARK: - App Lifecycle & Services Coordinator
final class ApplicationDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate, DeepLinkDelegate {
    
    private var attributionData: [AnyHashable: Any] = [:]
    private let trackingActivationKey = UIApplication.didBecomeActiveNotification
    
    private var deepLinkClickEvent: [String: Any] = [:]
    // Ключи для UserDefaults
    private let hasSentAttributionKey = "hasSentAttributionData"
    private let timerKey = "deepLinkMergeTimer"
    
    // Таймер
    private var mergeTimer: Timer?
    
    // MARK: - UIApplicationDelegate
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        FirebaseApp.configure()
        setupPushInfrastructure()
        bootstrapAppsFlyer()
        
        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            extractAndStoreDeepLink(from: remotePayload)
        }
        
        observeAppActivation()
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        extractAndStoreDeepLink(from: userInfo)
        completionHandler(.newData)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let payload = notification.request.content.userInfo
        extractAndStoreDeepLink(from: payload)
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        extractAndStoreDeepLink(from: response.notification.request.content.userInfo)
        completionHandler()
    }
    
    private func scheduleMergeTimer() {
        mergeTimer?.invalidate()
        mergeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            print("Таймер: deep link не пришёл → отправляем только attribution")
            self?.trySendMergedData()
        }
    }
    
    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { [weak self] token, error in
            guard error == nil, let token = token else { return }
            UserDefaults.standard.set(token, forKey: "fcm_token")
            UserDefaults.standard.set(token, forKey: "push_token")
        }
    }
    
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        attributionData = data
        // Запускаем таймер на 5 секунд
        scheduleMergeTimer()
        
        // Пробуем отправить сразу (если deep link уже есть)
        trySendMergedData()
        // broadcastAttributionUpdate(data: data)
    }
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status,
              let deepLinkObj = result.deepLink else { return }
        
        guard !UserDefaults.standard.bool(forKey: hasSentAttributionKey) else { return }
        
        deepLinkClickEvent = deepLinkObj.clickEvent
        
        NotificationCenter.default.post(name: Notification.Name("deeplink_values"), object: nil, userInfo: ["deeplinksData": deepLinkClickEvent])
        
        mergeTimer?.invalidate()
        
        trySendMergedData()
    }
    
    func onConversionDataFail(_ error: Error) {
        print("AppsFlyer attribution failed: \(error.localizedDescription)")
        broadcastAttributionUpdate(data: [:])
    }
    
    // MARK: - Private Setup
    private func setupPushInfrastructure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    private func bootstrapAppsFlyer() {
        AppsFlyerLib.shared()
            .configure { config in
                config.appsFlyerDevKey = AppKeys.devKey
                config.appleAppID = AppKeys.appId
                config.delegate = self
                config.deepLinkDelegate = self
            }
    }
    
    private func observeAppActivation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerTracking),
            name: trackingActivationKey,
            object: nil
        )
    }
    
    @objc private func triggerTracking() {
        if #available(iOS 14.0, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()  // ← СТАРТ ЗДЕСЬ, ОДИН РАЗ!
                }
            }
        }
    }
    
    private func extractAndStoreDeepLink(from payload: [AnyHashable: Any]) {
        var deepLink: String?
        
        if let url = payload["url"] as? String {
            deepLink = url
        } else if let data = payload["data"] as? [String: Any],
                  let url = data["url"] as? String {
            deepLink = url
        }
        
        if let link = deepLink {
            UserDefaults.standard.set(link, forKey: "temp_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LoadTempURL"),
                    object: nil,
                    userInfo: ["temp_url": link]
                )
            }
        }
    }
    
    private func broadcastAttributionUpdate(data: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: Notification.Name("ConversionDataReceived"),
            object: nil,
            userInfo: ["conversionData": data]
        )
    }
    
    // MARK: - Объединение и отправка
    private func trySendMergedData() {
        // Если уже отправляли — выходим
        guard !UserDefaults.standard.bool(forKey: hasSentAttributionKey) else { return }
        
        // Ждём хотя бы attribution
        guard !attributionData.isEmpty else { return }
        
        var merged = attributionData
        
        // Добавляем deep link только если он есть и ключей нет
        for (key, value) in deepLinkClickEvent {
            if merged[key] == nil {
                merged[key] = value
            }
        }
        
        // Отправляем
        broadcastAttributionUpdate(data: merged)
        
        // Сохраняем флаг
        UserDefaults.standard.set(true, forKey: hasSentAttributionKey)
        
        // Сбрасываем
        attributionData = [:]
        deepLinkClickEvent = [:]
        mergeTimer?.invalidate()
    }
    
}

private extension AppsFlyerLib {
    @discardableResult
    func configure(_ block: (AppsFlyerLib) -> Void) -> Self {
        block(self)
        return self
    }
}

//@main
//struct FeedMixChickApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}

extension Dictionary where Key == AnyHashable {
    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}
