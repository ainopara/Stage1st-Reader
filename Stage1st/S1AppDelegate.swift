//
//  S1AppDelegate.swift
//  Stage1st
//
//  Created by Zheng Li on 4/4/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack
import CrashlyticsLogger
import CloudKit
import AlamofireImage
import Fabric
import Crashlytics
import Reachability

// swiftlint:disable type_name
struct Constants {
    struct defaults {
        static let displayImageKey = "Display"
        static let removeTailsKey = "RemoveTails"
        static let precacheNextPageKey = "PrecacheNextPage"
        static let forcePortraitForPhoneKey = "ForcePortraitForPhone"
        static let nightModeKey = "NightMode"
        static let enableCloudKitSyncKey = "EnableSync"

        static let reverseActionKey = "Stage1st.Content.ReverseFloorAction"
        static let hideStickTopicsKey = "Stage1st.TopicList.HideStickTopics"

        static let historyLimitKey = "HistoryLimit"
        static let previousWebKitCacheCleaningDateKey = "PreviousWebKitCacheCleaningDate"
    }
}

// swiftlint:enable type_name

// MARK: -

@UIApplicationMain
final class S1AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private(set) var rootNavigationController: S1NavigationViewController?
    // swiftlint:disable weak_delegate
    private(set) var navigationControllerDelegate: NavigationControllerDelegate?
    // swiftlint:enable weak_delegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]? = nil) -> Bool {
        // Fabric
        #if DEBUG
        #else
        Fabric.with([Crashlytics.self])
        #endif

        setupLogging()

        // NSCoding Mapping
        NSKeyedUnarchiver.setClass(Floor.self, forClassName: "S1Floor")

        // UserDefaults
        let userDefaults = AppEnvironment.current.settings.defaults

        if userDefaults.value(forKey: "Order") == nil {
            let path = Bundle.main.path(forResource: "InitialOrder", ofType: "plist")!
            let orderArray = NSArray(contentsOfFile: path)
            userDefaults.set(orderArray, forKey: "Order")
        }

        if UI_USER_INTERFACE_IDIOM() == .pad {
            userDefaults.s1_setObjectIfNotExist(object: "18px", key: "FontSize")
        } else {
            userDefaults.s1_setObjectIfNotExist(object: "17px", key: "FontSize")
        }

        // TODO: Use register domain.
        userDefaults.s1_setObjectIfNotExist(object: NSNumber(value: -1), key: "HistoryLimit")
        userDefaults.register(defaults: [
            Constants.defaults.displayImageKey: true,
            Constants.defaults.removeTailsKey: true,
            Constants.defaults.precacheNextPageKey: true,
            Constants.defaults.forcePortraitForPhoneKey: true,
            Constants.defaults.nightModeKey: false,
            Constants.defaults.enableCloudKitSyncKey: false,

            Constants.defaults.reverseActionKey: false,
            Constants.defaults.hideStickTopicsKey: true,
        ])

        updateStage1stDomainIfNecessary()

        URLCache.shared.removeAllCachedResponses()
        URLCache.shared = ImageDownloader.defaultURLCache()

        // Start database & cloudKit (in order)
        DatabaseManager.initialize()
        if AppEnvironment.current.settings.enableCloudKitSync.value {
            AppEnvironment.current.cloudkitManager.setup()
//            CloudKitManager.initialize()
        }

        migrate()

        if AppEnvironment.current.settings.enableCloudKitSync.value {
            application.registerForRemoteNotifications()
        }

        // Setup Window
        let rootNavigationController = S1NavigationViewController(navigationBarClass: nil, toolbarClass: nil)
        self.navigationControllerDelegate = NavigationControllerDelegate(navigationController: rootNavigationController)
        rootNavigationController.delegate = self.navigationControllerDelegate
        rootNavigationController.viewControllers = [S1TopicListViewController(nibName: nil, bundle: nil)]
        rootNavigationController.isNavigationBarHidden = true
        self.rootNavigationController = rootNavigationController

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = rootNavigationController
        self.window?.makeKeyAndVisible()

        // Appearence
        ColorManager.shared.updateGlobalAppearance()
        navigationControllerDelegate!.setUpGagat()

        #if DEBUG
        let defaultsDictionary = AppEnvironment.current.settings.defaults.dictionaryRepresentation()
        let defaultsPlistData = try! PropertyListSerialization.data(fromPropertyList: defaultsDictionary, format: .xml, options: 0)
        let defaultsPlistString = String(data: defaultsPlistData, encoding: .utf8)!
        S1LogVerbose("Dump user defaults: \(defaultsPlistString)")
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reachabilityChanged),
            name: NSNotification.Name.init("kReachabilityChangedNotification"),
            object: nil
        )

        return true
    }

    @objc func reachabilityChanged(_ notification: Notification) {
        guard let reachability = notification.object as? Reachability else {
            assert(false, "this should never happen!")
            DDLogError("this should never happen!")
            return
        }

        if reachability.isReachableViaWiFi() {
            DDLogDebug("[Reachability] WIFI: display picture")
        } else {
            DDLogDebug("[Reachability] WWAN: display placeholder")
        }
    }
}

// MARK: Setup

extension S1AppDelegate {
    private func updateStage1stDomainIfNecessary() {
        let publicDatabase = AppEnvironment.current.cloudkitManager.cloudKitContainer.publicCloudDatabase
        let stage1stDomainRecordName = "cf531e8f-eb25-4931-ba11-73f8cd344d28"
        let stage1stDomainRecordID = CKRecordID(recordName: stage1stDomainRecordName)
        let fetchRecordOperation = CKFetchRecordsOperation(recordIDs: [stage1stDomainRecordID])

        fetchRecordOperation.fetchRecordsCompletionBlock = { recordsDictionary, error in
            guard let stage1stDomainRecord = recordsDictionary?[stage1stDomainRecordID] else {
                S1LogError("fetchedRecords: \(String(describing: recordsDictionary)) error: \(String(describing: error))")
                return
            }

            guard let serverAddress = ServerAddress(record: stage1stDomainRecord) else {
                S1LogError("[ServerAddressUpdate] Failed to parse server address from record: \(String(describing: recordsDictionary))")
                return
            }

            S1LogInfo("[ServerAddressUpdate] Updated \(serverAddress)")

            if serverAddress.isPrefered(to: AppEnvironment.current.serverAddress) {
                AppEnvironment.current.cacheDatabaseManager.set(serverAddress: serverAddress)
                AppEnvironment.current = Environment()

                DispatchQueue.main.async {
                    MessageHUD.shared.post(message: "论坛地址已更新，请重新启动应用。", duration: .second(2.0))
                }
            } else {
                S1LogInfo("[ServerAddressUpdate] Server address do not need to update.")
            }
        }

        publicDatabase.add(fetchRecordOperation)
    }
}

// MARK: Cleaning

extension S1AppDelegate {
    func applicationDidEnterBackground(_ application: UIApplication) {
        AppEnvironment.current.dataCenter.cleaning()
    }
}

// MARK: URL Scheme

extension S1AppDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        S1LogDebug("[URL Scheme] \(url) from \(String(describing: options[.sourceApplication]))")

        if
            url.host == "open",
            let queries = S1Parser.extractQuerys(fromURLString: url.absoluteString),
            let topicIDString = queries["tid"],
            let topicID = Int(topicIDString)
        {
            let topic = AppEnvironment.current.dataCenter.traced(topicID: topicID) ?? S1Topic(topicID: NSNumber(value: topicID))
            pushContentViewController(for: topic)
            return true
        }

        return true
    }

    func pushContentViewController(for topic: S1Topic) {
        guard let rootNavigationController = self.window?.rootViewController as? UINavigationController else {
            return
        }

        let contentViewController = S1ContentViewController(topic: topic, dataCenter: AppEnvironment.current.dataCenter)
        rootNavigationController.pushViewController(contentViewController, animated: true)
    }
}

// MARK: Hand Off

extension S1AppDelegate {
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        // TODO: Show an alert to tell user we are restoring state from hand off here.
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        S1LogDebug("Receive Hand Off: \(String(describing: userActivity.userInfo))")

        guard
            let userInfo = userActivity.userInfo,
            let topicID = userInfo["topicID"] as? Int,
            let page = userInfo["page"] as? Int
        else {
            // TODO: Show an alert to tell user something is wrong.
            return true
        }

        var topic = AppEnvironment.current.dataCenter.traced(topicID: topicID) ?? S1Topic(topicID: NSNumber(value: topicID))
        topic = topic.copy() as! S1Topic // To make it mutable
        topic.lastViewedPage = NSNumber(value: page)

        pushContentViewController(for: topic)

        return true
    }
}

// MARK: Background Refresh

extension S1AppDelegate {
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        S1LogInfo("[Backgournd Fetch] fetch called")
        completionHandler(.noData)
        // TODO: user forum notification can be fetched here, then send a local notification to user.
    }
}

// MARK: Logging
extension S1AppDelegate {

    @objc func setupLogging() {

        #if DEBUG

        defaultDebugLevel = .verbose

        let formatter = DDMultiFormatter()
        formatter.add(FileLogFormatter())
        let queueFormatter = DispatchQueueLogFormatter()
        queueFormatter?.setReplacementString("cloudkit", forQueueLabel: "com.ainopara.stage1st.cloudkit")
        formatter.add(queueFormatter)
        formatter.add(ErrorLevelLogFormatter())

        let osLogger = OSLogger.shared
        osLogger.register(tags: [
            S1LoggerTag(subsystem: .default, category: .network),
            S1LoggerTag(subsystem: .default, category: .interaction),
            S1LoggerTag(subsystem: .default, category: .environment),
            S1LoggerTag(subsystem: .default, category: .extension),
            S1LoggerTag(subsystem: .default, category: .ui),
            S1LoggerTag(subsystem: .default, category: .cloudkit)
        ])
        osLogger.logFormatter = formatter
        DDLog.add(osLogger)

        #else

        defaultDebugLevel = .debug

        let formatter = DDMultiFormatter()
        formatter.add(FileLogFormatter())
        let queueFormatter = DispatchQueueLogFormatter()
        queueFormatter?.setReplacementString("cloudkit", forQueueLabel: "com.ainopara.stage1st.cloudkit")
        formatter.add(queueFormatter)
        formatter.add(ErrorLevelLogFormatter())

        let logger = CrashlyticsLogger.shared
        logger.logFormatter = formatter
        DDLog.add(logger)

        #endif
    }
}

// MARK: Migration
extension S1AppDelegate {

    @objc func migrate() {
        migrateTo3400()
        migrateTo3600()
        migrateTo3700()
        migrateTo3800()
        migrateTo3900()
        migrateTo3940()
    }

    private func migrateTo3400() {
        guard
            let orderArray = UserDefaults.standard.value(forKey: "Order") as? [[String]],
            let firstArray = orderArray.first,
            let secondArray = orderArray.last
        else {
            return
        }

        if !firstArray.contains("模玩专区") && !secondArray.contains("模玩专区") {
            S1LogDebug("Update Order List")
            guard
                let path = Bundle.main.path(forResource: "InitialOrder", ofType: "plist"),
                let order = NSArray(contentsOfFile: path)
            else {
                return
            }

            UserDefaults.standard.set(order, forKey: "Order")
            UserDefaults.standard.removeObject(forKey: "UserID")
            UserDefaults.standard.removeObject(forKey: "UserPassword")
        }
    }

    private func migrateTo3600() {
        S1Tracer.upgradeDatabase()
    }

    private func migrateTo3700() {
        if UI_USER_INTERFACE_IDIOM() == .pad && UserDefaults.standard.object(forKey: "FontSize") as? String == "17px" {
            UserDefaults.standard.set("18px", forKey: "FontSize")
        }
    }

    private func migrateTo3800() {
        guard
            let orderForumArray = UserDefaults.standard.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("真碉堡山") {
            UserDefaults.standard.set([displayForumArray, hiddenForumArray + ["真碉堡山"]], forKey: "Order")
        }
    }

    private func migrateTo3900() {
        guard
            let orderForumArray = UserDefaults.standard.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("DOTA") {
            UserDefaults.standard.set([displayForumArray, hiddenForumArray + ["DOTA", "欧美动漫"]], forKey: "Order")
        }
    }

    private func migrateTo3940() {
        guard
            let orderForumArray = UserDefaults.standard.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("泥潭") {
            UserDefaults.standard.set([displayForumArray, hiddenForumArray + ["泥潭"]], forKey: "Order")
        }
    }
}

// MARK: Push Notification For CloudKit Sync

extension S1AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        S1LogDebug("[APNS] Registered for Push notifications with token: \(deviceToken)", category: .cloudkit)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        S1LogWarn("[APNS] Push subscription failed: \(error)", category: .cloudkit)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        S1LogDebug("[APNS] Push received: \(userInfo)", category: .cloudkit)
        if !UserDefaults.standard.bool(forKey: "EnableSync") {
            DDLogWarn("[APNS] push notification received when user do not enable sync feature.")
            completionHandler(.noData)
            return
        }

        AppEnvironment.current.cloudkitManager.fetchRecordChange { (fetchResult) in
            completionHandler(fetchResult.toUIBackgroundFetchResult())
        }
    }
}

// MARK: -

fileprivate extension UserDefaults {
    func s1_setObjectIfNotExist(object: Any, key: String) {
        if value(forKey: key) == nil {
            `set`(object, forKey: key)
        }
    }
}
