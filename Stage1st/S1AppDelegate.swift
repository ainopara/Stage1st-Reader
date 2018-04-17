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

// swiftlint:disable type_name
struct Constants {
    struct defaults {
        static let displayImageKey = "Display"
        static let showsReplyIncrementKey = "ReplyIncrement"
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

// MARK: Logging
extension S1AppDelegate {

    @objc func setupLogging() {

        #if DEBUG
            defaultDebugLevel = .verbose

            let formatter = DDMultiFormatter()
            formatter.add(FileLogFormatter())
            formatter.add(DispatchQueueLogFormatter())
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
            formatter.add(DispatchQueueLogFormatter())
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
        let orderArray = UserDefaults.standard.value(forKey: "Order")
    }

    private func migrateTo3600() {

    }

    private func migrateTo3700() {

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

// MARK: Setup
extension S1AppDelegate {
    @objc func setup() {
        // NSCoding Mapping
        NSKeyedUnarchiver.setClass(Floor.self, forClassName: "S1Floor")

        // UserDefaults
        let userDefaults = UserDefaults.standard

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
        UserDefaults.standard.register(defaults: [
            Constants.defaults.displayImageKey: true,
            Constants.defaults.showsReplyIncrementKey: true,
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
    }

    private func updateStage1stDomainIfNecessary() {
        let publicDatabase = CKContainer.default().publicCloudDatabase
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

extension S1AppDelegate {
    @objc func notifyCleaning() {
        AppEnvironment.current.dataCenter.cleaning()
    }
}

fileprivate extension UserDefaults {
    func s1_setObjectIfNotExist(object: Any, key: String) {
        if value(forKey: key) == nil {
            `set`(object, forKey: key)
        }
    }
}

// MRRK: - Push Notification For Sync

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

        AppEnvironment.current.cloudkitManager.fetchRecordChange(completion: completionHandler)
    }
}
