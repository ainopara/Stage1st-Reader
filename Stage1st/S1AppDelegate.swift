//
//  S1AppDelegate.swift
//  Stage1st
//
//  Created by Zheng Li on 4/4/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Ainoaibo
import CocoaLumberjack
import CrashlyticsLogger
import CloudKit
import Fabric
import Crashlytics
import Reachability
import Kingfisher

#if DEBUG
import OHHTTPStubs
#endif

@UIApplicationMain
final class S1AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private(set) var rootNavigationController: RootNavigationController?
    // swiftlint:disable weak_delegate
    private(set) var navigationControllerDelegate: NavigationControllerDelegate?
    // swiftlint:enable weak_delegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Fabric
        #if DEBUG
        #else
        Fabric.with([Crashlytics.self])
        #endif

        setupLogging()

        #if DEBUG
        if let isSnapshotTest = ProcessInfo().environment["STAGE1ST_SNAPSHOT_TEST"], isSnapshotTest == "true" {
            prepareForSnapshotTest()
        }
        #endif

        // UserDefaults Initialize
        let userDefaults = AppEnvironment.current.settings.defaults

        if userDefaults.value(forKey: "Order") == nil {
            let path = Bundle.main.path(forResource: "InitialOrder", ofType: "plist")!
            let orderArray = NSArray(contentsOfFile: path)
            userDefaults.set(orderArray, forKey: "Order")
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            userDefaults.s1_setObjectIfNotExist(object: "18px", key: "FontSize")
        } else {
            userDefaults.s1_setObjectIfNotExist(object: "17px", key: "FontSize")
        }

        updateStage1stDomainIfNecessary()

        URLCache.shared = URLCache(
            memoryCapacity: 20 * 1024 * 1024, // 20 MB
            diskCapacity: 150 * 1024 * 1024,  // 150 MB
            diskPath: "org.alamofire.imagedownloader"
        )

        migrate()

        if AppEnvironment.current.settings.enableCloudKitSync.value {
            AppEnvironment.current.cloudkitManager.setup()
            application.registerForRemoteNotifications()
        }

        // Setup Window
        self.window = DarkModeDetectWindow(frame: UIScreen.main.bounds)

        let rootNavigationController = RootNavigationController(rootViewController: ContainerViewController(nibName: nil, bundle: nil))
        self.navigationControllerDelegate = NavigationControllerDelegate(navigationController: rootNavigationController)
        rootNavigationController.delegate = self.navigationControllerDelegate
        self.rootNavigationController = rootNavigationController

        self.window!.rootViewController = rootNavigationController
        self.window!.makeKeyAndVisible()
        AppEnvironment.current.colorManager.window = self.window!

        // Appearence
        AppEnvironment.current.colorManager.updateGlobalAppearance()

        #if DEBUG
        let defaultsDictionary = AppEnvironment.current.settings.defaults.dictionaryRepresentation()
        let defaultsPlistData = try! PropertyListSerialization.data(fromPropertyList: defaultsDictionary, format: .xml, options: 0)
        let defaultsPlistString = String(data: defaultsPlistData, encoding: .utf8)!
        S1LogVerbose("Dump user defaults: \(defaultsPlistString)")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reachabilityChanged),
            name: .reachabilityChanged,
            object: nil
        )

        #endif

        return true
    }

    @objc func reachabilityChanged(_ notification: Notification) {
        guard let reachability = notification.object as? Reachability else {
            assert(false, "this should never happen!")
            S1LogError("this should never happen!")
            return
        }

        if reachability.isReachableViaWiFi() {
            S1LogDebug("[Reachability] WIFI: display picture")
        } else {
            S1LogDebug("[Reachability] WWAN: display placeholder")
        }
    }
}

// MARK: Setup

extension S1AppDelegate {

    private func updateStage1stDomainIfNecessary() {
        let publicDatabase = AppEnvironment.current.cloudkitManager.cloudKitContainer.publicCloudDatabase
        let stage1stDomainRecordName = "cf531e8f-eb25-4931-ba11-73f8cd344d28"
        let stage1stDomainRecordID = CKRecord.ID(recordName: stage1stDomainRecordName)
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
                AppEnvironment.replaceCurrent(with: Environment())

                DispatchQueue.main.async {
                    Toast.shared.post(message: "论坛地址已更新，请重新启动应用。", duration: .second(2.0))
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

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        S1LogDebug("[URL Scheme] \(url) from \(String(describing: options[.sourceApplication]))")

        let queries = Parser.extractQuerys(from: url.absoluteString)
        if
            url.host == "open",
            let topicIDString = queries["tid"],
            let topicID = Int(topicIDString)
        {
            let topic = AppEnvironment.current.dataCenter.traced(topicID: topicID) ?? S1Topic(topicID: NSNumber(value: topicID))
            pushContentViewController(for: topic)
            return true
        }

        return true
    }

    private func pushContentViewController(for topic: S1Topic) {
        guard let rootNavigationController = self.rootNavigationController else {
            return
        }

        let contentViewController = ContentViewController(topic: topic)
        rootNavigationController.pushViewController(contentViewController, animated: true)
    }
}

// MARK: Hand Off

extension S1AppDelegate {

    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        // TODO: Show an alert to tell user we are restoring state from hand off here.
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
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

        dynamicLogLevel = .debug

        let formatter = DDMultiFormatter()
        let queueFormatter = DispatchQueueLogFormatter()
        queueFormatter?.setReplacementString("cloudkit", forQueueLabel: "com.ainopara.stage1st.cloudkit")
        formatter.add(queueFormatter)
        formatter.add(ErrorLevelLogFormatter())

        let osLogger = OSLogger.shared
        osLogger.logFormatter = formatter
        DDLog.add(osLogger)

        let inMemoryLogFormatter = DDMultiFormatter()
        inMemoryLogFormatter.add(FileLogFormatter())
        inMemoryLogFormatter.add(queueFormatter)
        inMemoryLogFormatter.add(ErrorLevelLogFormatter())
        inMemoryLogFormatter.add(DateLogFormatter())

        let inMemoryLogger = InMemoryLogger.shared
        inMemoryLogger.logFormatter = inMemoryLogFormatter
        DDLog.add(inMemoryLogger)

        #else

        dynamicLogLevel = .debug

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
        migrateTo3_7()
        migrateTo3_8()
        migrateTo3_9()
        migrateTo3_9_4()
        migrateTo3_12_2()
        migrateTo3_14()
    }

    private func migrateTo3_7() {
        let userDefaults = AppEnvironment.current.settings.defaults
        if UIDevice.current.userInterfaceIdiom == .pad && userDefaults.object(forKey: "FontSize") as? String == "17px" {
            userDefaults.set("18px", forKey: "FontSize")
        }
    }

    private func migrateTo3_8() {
        let userDefaults = AppEnvironment.current.settings.defaults
        guard
            let orderForumArray = userDefaults.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("真碉堡山") {
            userDefaults.set([displayForumArray, hiddenForumArray + ["真碉堡山"]], forKey: "Order")
        }
    }

    private func migrateTo3_9() {
        let userDefaults = AppEnvironment.current.settings.defaults
        guard
            let orderForumArray = userDefaults.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else
        {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("DOTA") {
            userDefaults.set([displayForumArray, hiddenForumArray + ["DOTA", "欧美动漫"]], forKey: "Order")
        }
    }

    private func migrateTo3_9_4() {
        let userDefaults = AppEnvironment.current.settings.defaults
        guard
            let orderForumArray = userDefaults.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else
        {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("泥潭") {
            userDefaults.set([displayForumArray, hiddenForumArray + ["泥潭"]], forKey: "Order")
        }
    }

    private func migrateTo3_12_2() {
        let cacheDatabaseManager = AppEnvironment.current.cacheDatabaseManager
        let mahjongFaceItems = cacheDatabaseManager.mahjongFaceHistoryV2().map { item in MahjongFaceInputView.HistoryItem(id: item.key) }
        cacheDatabaseManager.set(mahjongFaceHistory: cacheDatabaseManager.mahjongFaceHistory() + mahjongFaceItems)
        cacheDatabaseManager.set(mahjongFaceHistoryV2: [])
    }

    private func migrateTo3_14() {
        let userDefaults = AppEnvironment.current.settings.defaults
        guard
            let orderForumArray = userDefaults.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2
        else {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }

        var displayForumArray = orderForumArray[0]
        var hiddenForumArray = orderForumArray[1]

        if !(displayForumArray + hiddenForumArray).contains("卓明谷") {
            displayForumArray = displayForumArray.map {
                if $0 == "外野" {
                    return "卓明谷"
                } else {
                    return $0
                }
            }

            hiddenForumArray = hiddenForumArray.map {
                if $0 == "外野" {
                    return "卓明谷"
                } else {
                    return $0
                }
            }
            userDefaults.set([displayForumArray, hiddenForumArray + ["火星里侧", "菠菜"]], forKey: "Order")
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
        if !AppEnvironment.current.settings.enableCloudKitSync.value {
            S1LogWarn("[APNS] push notification received when user do not enable sync feature.")
            completionHandler(.noData)
            return
        }

        AppEnvironment.current.cloudkitManager.setNeedsFetchChanges { (fetchResult) in
            completionHandler(fetchResult.toUIBackgroundFetchResult())
        }
    }
}

// MARK: Snapshot Test Support

#if DEBUG

import SWHttpTrafficRecorder

extension S1AppDelegate {

    private func prepareForSnapshotTest() {
        URLCache.shared.removeAllCachedResponses()
        let sessionConfiguration = URLSessionConfiguration.af.default

        let fixtureFolder = URL(fileURLWithPath: String(#file))
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Stage1stTests")
                    .appendingPathComponent("Fixtures")
                    .appendingPathComponent("SnapshotResponse")

        func record() {
            SWHttpTrafficRecorder.shared().recordingFormat = .httpMessage
            try! SWHttpTrafficRecorder.shared().startRecording(atPath: fixtureFolder.path, for: sessionConfiguration)
            SWHttpTrafficRecorder.shared().fileNamingBlock = { (request, response, defaultName) in
                return RequestNameGenerator.name(for: request!) + ".response"
            }
        }

        func replay() {
            stub(condition: isHost("bbs.saraba1st.com")) { (request) -> OHHTTPStubsResponse in
                let stubName = RequestNameGenerator.name(for: request)
                S1LogDebug("\(stubName) <- \(request.url!.absoluteString)")
                let stubURL = fixtureFolder.appendingPathComponent(stubName).appendingPathExtension("response")
                do {
                    let data = try Data(contentsOf: stubURL)
                    return OHHTTPStubsResponse(httpMessageData: data)
                } catch {
                    return OHHTTPStubsResponse(error: error)
                }
            }
        }

//        record()
        replay()

        AppEnvironment.replaceCurrent(with: Environment(
            databaseName: "SnapshotYap.sqlite",
            cacheDatabaseName: "SnapshotCache.sqlite",
            grdbName: "SnapshotGRDB.sqlite",
            sessionConfiguration: sessionConfiguration,
            settings: Stage1stSettings(defaults: UserDefaults(suiteName: "snapshot")!)
        ))

        AppEnvironment.current.databaseManager.bgDatabaseConnection.readWrite { (transaction) in
            transaction.removeAllObjectsInAllCollections()
        }
        AppEnvironment.current.cacheDatabaseManager.removeAllData()
    }
}

#endif

// MARK: -

private extension UserDefaults {

    func s1_setObjectIfNotExist(object: Any, key: String) {
        if value(forKey: key) == nil {
            `set`(object, forKey: key)
        }
    }
}
