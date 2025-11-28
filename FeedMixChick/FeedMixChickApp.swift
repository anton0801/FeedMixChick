import SwiftUI
import UIKit
import Firebase
import UserNotifications
import AppsFlyerLib
import AppTrackingTransparency

final class ApplicationDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate, DeepLinkDelegate {
    
    static var orientationLock = UIInterfaceOrientationMask.all
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return ApplicationDelegate.orientationLock
    }
    
    private var attributionData: [AnyHashable: Any] = [:]
    private let trackingActivationKey = UIApplication.didBecomeActiveNotification
    
    private var dlData: [String: Any] = [:]
    private let hasSentAttributionKey = "hasSentAttributionData"
    private let timerKey = "deepLinkMergeTimer"
    
    private var mergeTimer: Timer?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        FirebaseApp.configure()
        
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
        
        AppsFlyerLib.shared()
            .configure { config in
                config.appsFlyerDevKey = AppKeys.devKey
                config.appleAppID = AppKeys.appId
                config.delegate = self
                config.deepLinkDelegate = self
            }
        
        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            extractStoreDL(from: remotePayload)
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
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        extractStoreDL(from: userInfo)
        completionHandler(.newData)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let payload = notification.request.content.userInfo
        extractStoreDL(from: payload)
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        extractStoreDL(from: response.notification.request.content.userInfo)
        completionHandler()
    }
    
    private func scheduleMergeTimer() {
        mergeTimer?.invalidate()
        mergeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.trySendMergedData()
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { [weak self] token, error in
            guard error == nil, let token = token else { return }
            UserDefaults.standard.set(token, forKey: "push_token")
            UserDefaults.standard.set(token, forKey: "fcm_token")
        }
    }
    
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        attributionData = data
        scheduleMergeTimer()
        trySendMergedData()
    }
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status,
              let deepLinkObj = result.deepLink else { return }
        guard !UserDefaults.standard.bool(forKey: hasSentAttributionKey) else { return }
        dlData = deepLinkObj.clickEvent
        NotificationCenter.default.post(name: Notification.Name("deeplink_values"), object: nil, userInfo: ["deeplinksData": dlData])
        mergeTimer?.invalidate()
        trySendMergedData()
    }
    
    func onConversionDataFail(_ error: Error) {
        sendDataToApp(data: [:])
    }
    
    private func observeAppActivation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerTracking),
            name: trackingActivationKey,
            object: nil
        )
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
    }
    
    private func extractStoreDL(from payload: [AnyHashable: Any]) {
        var dl: String?
        
        if let url = payload["url"] as? String {
            dl = url
        } else if let data = payload["data"] as? [String: Any],
                  let url = data["url"] as? String {
            dl = url
        }
        
        if let link = dl {
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
    
    private func sendDataToApp(data: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: Notification.Name("ConversionDataReceived"),
            object: nil,
            userInfo: ["conversionData": data]
        )
    }
    
    private func trySendMergedData() {
        var merged = attributionData
        for (key, value) in dlData {
            if merged[key] == nil {
                merged[key] = value
            }
        }
        sendDataToApp(data: merged)
        UserDefaults.standard.set(true, forKey: hasSentAttributionKey)
        attributionData = [:]
        dlData = [:]
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
