//
//  AppDelegate.swift
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
import Sentry
import Keys

#if DEBUG
import OHHTTPStubs
#endif

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private(set) var rootNavigationController: RootNavigationController?
    // swiftlint:disable weak_delegate
    private(set) var navigationControllerDelegate: NavigationControllerDelegate?
    // swiftlint:enable weak_delegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        setupLogging()
        setupCrashReporters()

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

        AppEnvironment.current.eventTracker.logEvent("Active", attributes: ["from": "void"], uploadImmediately: true)

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

extension AppDelegate {

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

// MARK:

extension AppDelegate {

    func applicationWillEnterForeground(_ application: UIApplication) {
        AppEnvironment.current.eventTracker.logEvent("Active", attributes: ["from": "background"], uploadImmediately: true)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AppEnvironment.current.eventTracker.logEvent("Inactive", uploadImmediately: true)
        AppEnvironment.current.dataCenter.cleaning()
    }
}

// MARK: URL Scheme

extension AppDelegate {

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

extension AppDelegate {

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

extension AppDelegate {

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        S1LogInfo("[Backgournd Fetch] fetch called")
        completionHandler(.noData)
        // TODO: user forum notification can be fetched here, then send a local notification to user.
    }
}

// MARK: Logging

private extension AppDelegate {

    func setupLogging() {

        dynamicLogLevel = .debug

        let errorLevelFormatter = ErrorLevelLogFormatter()
        let fileLogFormatter = FileLogFormatter()
        let queueFormatter = DispatchQueueLogFormatter()
        queueFormatter.setReplacementString("cloudkit", forQueueLabel: "com.ainopara.stage1st.cloudkit")
        let dateLogFormatter = DateLogFormatter()

        func setupSentryLogger() {
            let sentryLogFormatter = DDMultiFormatter()
            sentryLogFormatter.add(fileLogFormatter)
            sentryLogFormatter.add(queueFormatter)

            let sentryLogger = SentryBreadcrumbsLogger.shared
            sentryLogger.logFormatter = sentryLogFormatter
            DDLog.add(sentryLogger)
        }

        #if DEBUG

        func setupOSLogger() {
            let osLoggerFormatter = DDMultiFormatter()
            osLoggerFormatter.add(queueFormatter)
            osLoggerFormatter.add(errorLevelFormatter)

            let osLogger = OSLogger.shared
            osLogger.logFormatter = osLoggerFormatter
            DDLog.add(osLogger)
        }

        func setupInMemoryLogger() {
            let inMemoryLogFormatter = DDMultiFormatter()
            inMemoryLogFormatter.add(fileLogFormatter)
            inMemoryLogFormatter.add(queueFormatter)
            inMemoryLogFormatter.add(errorLevelFormatter)
            inMemoryLogFormatter.add(dateLogFormatter)

            let inMemoryLogger = InMemoryLogger.shared
            inMemoryLogger.logFormatter = inMemoryLogFormatter
            DDLog.add(inMemoryLogger)
        }

        setupOSLogger()
        setupInMemoryLogger()
        setupSentryLogger()

        #else

        func setupCrashlyticsLogger() {
            let formatter = DDMultiFormatter()
            formatter.add(fileLogFormatter)
            formatter.add(queueFormatter)
            formatter.add(errorLevelFormatter)

            let logger = CrashlyticsLogger.shared
            logger.logFormatter = formatter
            DDLog.add(logger)
        }

        setupCrashlyticsLogger()
        setupSentryLogger()
        #endif
    }

    func setupCrashReporters() {

        /// Setup Crashlytics

        #if DEBUG
        #else
        Fabric.with([Crashlytics.self])
        #endif

        /// Setup Sentry

        if !Stage1stKeys().sentryDSN.isEmpty {
            do {
                Client.shared = try Client(dsn: Stage1stKeys().sentryDSN)
                Client.shared?.enableAutomaticBreadcrumbTracking()
                Client.shared?.maxEvents = 100
                Client.shared?.maxBreadcrumbs = 100
                Client.shared?.shouldQueueEvent = { (event, response, error) in
                    // Taken from Apple Docs:
                    // If a response from the server is received, regardless of whether the request completes successfully or fails,
                    // the response parameter contains that information.
                    guard let response = response else {
                        // In case response is nil, we want to queue the event locally since this
                        // indicates no internet connection
                        return true
                    }

                    if response.statusCode == 429 {
                        S1LogError("Rate limit reached, event will be stored and sent later")
                        return true
                    }
                    // In all other cases we don't want to retry sending it and just discard the event

                    if response.statusCode != 200 {
                        let nsError = NSError(domain: "SentryDropEventOnFirstAttempt", code: 0, userInfo: [
                            "release": event.releaseName ?? "",
                            "response": "\(response)",
                            "responseCode": "\(response.statusCode)",
                            "X-Sentry-Error": String(describing: response.value(forHTTPHeaderField: "X-Sentry-Error")),
                            "message": event.message,
                            "level": event.level.rawValue,
                            "error": "\(String(describing: error))"
                        ])
                        Crashlytics.sharedInstance().recordError(nsError)
                    }

                    return false
                }

                Client.shared?.willDropEvent = { (eventDict, response, error) in
                    let nsError = NSError(domain: "SentryDropEventOnSendAllPhase", code: 0, userInfo: [
                        "release": eventDict["release"] ?? "",
                        "response": "\(String(describing: response))",
                        "responseCode": "\(String(describing: response?.statusCode))",
                        "X-Sentry-Error": String(describing: response?.value(forHTTPHeaderField: "X-Sentry-Error")),
                        "message": eventDict["message"] ?? "",
                        "level": eventDict["level"] ?? "",
                        "error": "\(String(describing: error))"
                    ])
                    Crashlytics.sharedInstance().recordError(nsError)
                }

                try Client.shared?.startCrashHandler()
            } catch let error {
                S1LogError("Failed to setup sentry: \(error)")
            }

            #if DEBUG
            Client.shared?.environment = "development"
            Client.logLevel = .verbose
            #else
            Client.shared?.environment = "production"
            #endif
        }
    }
}

// MARK: Push Notification For CloudKit Sync

extension AppDelegate {

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

extension AppDelegate {

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
