//
//  AppDelegate.swift
//  Stage1st
//
//  Created by Zheng Li on 4/4/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Ainoaibo
import Combine
import CocoaLumberjack
import CloudKit
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

        if UIDevice.current.userInterfaceIdiom == .pad {
            userDefaults.s1_setObjectIfNotExist(object: "18px", key: "FontSize")
        } else {
            userDefaults.s1_setObjectIfNotExist(object: "17px", key: "FontSize")
        }

        updateStage1stDomainIfNecessary()
        updateStage1stForumListIfNecessary()

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

        _ = NotificationCenter.default.publisher(for: .reachabilityChanged)
            .sink(receiveValue: { notification in
                guard let reachability = notification.object as? Reachability else {
                    assertionFailure()
                    return
                }

                if reachability.isReachableViaWiFi() {
                    S1LogDebug("[Reachability] WIFI: display picture")
                } else {
                    S1LogDebug("[Reachability] WWAN: display placeholder")
                }
            })

        #endif

        AppEnvironment.current.eventTracker.logEvent("Active", attributes: ["from": "void"], uploadImmediately: true)

        return true
    }

    @objc func reachabilityChanged(_ notification: Notification) {

    }
}

extension AppDelegate {

    func applicationWillEnterForeground(_ application: UIApplication) {
        S1LogDebug("applicationWillEnterForeground")
        AppEnvironment.current.eventTracker.logEvent("Active", attributes: ["from": "background"], uploadImmediately: true)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        S1LogDebug("applicationDidEnterBackground")
        AppEnvironment.current.dataCenter.cleaning()
    }

    // MARK: URL Scheme

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

    // MARK: Hand Off

    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        // TODO: Show an alert to tell user we are restoring state from hand off here.
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        S1LogDebug("Receive Hand Off: \(String(describing: userActivity.userInfo))")

        guard
            let userInfo = userActivity.userInfo,
            let topicID = userInfo["topicID"] as? Int
        else {
            // TODO: Show an alert to tell user something is wrong.
            return true
        }

        var topic = AppEnvironment.current.dataCenter.traced(topicID: topicID) ?? S1Topic(topicID: NSNumber(value: topicID))
        topic = topic.copy() as! S1Topic // To make it mutable
        if let page = userInfo["page"] as? Int {
            topic.lastViewedPage = NSNumber(value: page)
        }

        pushContentViewController(for: topic)

        return true
    }

    // MARK: Background Refresh

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        S1LogInfo("[Backgournd Fetch] fetch called")
        completionHandler(.noData)
        // TODO: user forum notification can be fetched here, then send a local notification to user.
    }

    // MARK: Push Notification For CloudKit Sync

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

// MARK: - Setup

struct ForumInfo: Codable, Equatable {
    let id: Int
    let name: String
}

struct ForumBundle: Codable, Equatable {
    let date: Date
    let forums: [ForumInfo]
}

private extension AppDelegate {

    func updateStage1stDomainIfNecessary() {
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

    func updateStage1stForumListIfNecessary() {
        let publicDatabase = AppEnvironment.current.cloudkitManager.cloudKitContainer.publicCloudDatabase
        let forumInfoRecordID = CKRecord.ID(recordName: "4D943341-1910-3C82-8240-B74DDCED151F")
        let fetchRecordOperation = CKFetchRecordsOperation(recordIDs: [forumInfoRecordID])

        fetchRecordOperation.fetchRecordsCompletionBlock = { recordsDictionary, error in
            guard let forumInfoRecord = recordsDictionary?[forumInfoRecordID], let jsonString = forumInfoRecord["json"] as? String else {
                S1LogError("fetchedRecords: \(String(describing: recordsDictionary)) error: \(String(describing: error))")
                return
            }

            let result: Result<[ForumInfo], Error> = tryToResult {
                let decoder = JSONDecoder()
                return try decoder.decode([ForumInfo].self, from: jsonString.data(using: .utf8) ?? Data())
            }

            guard case .success(let forumInfos) = result else {
                S1LogError("Failed to parse server address from record: \(String(describing: recordsDictionary)), \(result)")
                return
            }

            let bundle = ForumBundle(date: forumInfoRecord.modificationDate ?? .distantPast, forums: forumInfos)
            let currentBundleData = AppEnvironment.current.settings.forumBundle.value
            let decoder = JSONDecoder()
            if
                let currentBundle = try? decoder.decode(ForumBundle.self, from: currentBundleData),
                currentBundle.date.timeIntervalSince(bundle.date) >= 0
            {
                S1LogInfo("No need to update forum because \(currentBundle.date) is greater than or equal to \(bundle.date)")
                return
            }

            let encodedData: Result<Data, Error> = tryToResult {
                let encoder = JSONEncoder()
                return try encoder.encode(bundle)
            }
            guard case .success(let data) = encodedData else {
                S1LogError("Failed to encode \(bundle) with error: \(result)")
                return
            }
            S1LogInfo("Updated \(forumInfos)")
            AppEnvironment.current.settings.forumBundle.value = data
        }

        publicDatabase.add(fetchRecordOperation)
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
        #endif

        setupSentryLogger()
    }

    func setupCrashReporters() {
        if !Stage1stKeys().sentryDSN.isEmpty {
            let env: String = {
                #if DEBUG
                return "development"
                #else
                return "production"
                #endif
            }()

            SentrySDK.start { (options) in
                options.dsn = Stage1stKeys().sentryDSN
                options.environment = env
                options.maxBreadcrumbs = 150
                options.beforeSend = { event in
                    if
                        let threads = event.threads,
                        threads.count == 1,
                        let debugMeta = event.debugMeta,
                        debugMeta.count == 1
                    {
                        event.threads = nil
                        event.debugMeta = nil
                    }
                    return event
                }
            }
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

// MARK: - Helpers

private extension UserDefaults {

    func s1_setObjectIfNotExist(object: Any, key: String) {
        if value(forKey: key) == nil {
            `set`(object, forKey: key)
        }
    }
}

func tryToResult<T>(block: () throws -> T) -> Result<T, Error> {
    do {
        return .success(try block())
    } catch {
        return .failure(error)
    }
}
