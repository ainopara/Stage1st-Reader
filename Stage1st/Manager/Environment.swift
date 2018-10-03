//
//  Environment.swift
//  Stage1st
//
//  Created by Zheng Li on 13/03/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation
import Reachability

@objcMembers
class Environment: NSObject {
    let forumName: String
    let serverAddress: ServerAddress
    let cookieStorage: HTTPCookieStorage
    let settings: Stage1stSettings
    let reachability: Reachability
    let apiService: DiscuzClient
    let networkManager: S1NetworkManager
    let webKitImageDownloader: WebKitImageDownloader
    let databaseManager: DatabaseManager
    let cloudkitManager: CloudKitManager
    let cacheDatabaseManager: CacheDatabaseManager
    let colorManager: ColorManager
    let eventTracker: EventTracker

    let databaseAdapter: S1YapDatabaseAdapter
    let dataCenter: DataCenter

    init(
        forumName: String,
        serverAddress: ServerAddress,
        cookieStorage: HTTPCookieStorage,
        settings: Stage1stSettings,
        reachability: Reachability,
        apiService: DiscuzClient,
        networkManager: S1NetworkManager,
        webKitImageDownloader: WebKitImageDownloader,
        databaseManager: DatabaseManager,
        cloudkitManager: CloudKitManager,
        cacheDatabaseManager: CacheDatabaseManager,
        colorManager: ColorManager,
        eventTracker: EventTracker,
        databaseAdapter: S1YapDatabaseAdapter,
        dataCenter: DataCenter
    ) {
        self.forumName = forumName
        self.serverAddress = serverAddress
        self.cookieStorage = cookieStorage
        self.settings = settings
        self.reachability = reachability
        reachability.startNotifier()
        self.apiService = apiService
        self.networkManager = networkManager
        self.webKitImageDownloader = webKitImageDownloader
        self.databaseManager = databaseManager
        self.cloudkitManager = cloudkitManager
        self.cacheDatabaseManager = cacheDatabaseManager
        self.colorManager = colorManager
        self.eventTracker = eventTracker
        self.databaseAdapter = databaseAdapter
        self.dataCenter = dataCenter
    }

    init(
        forumName: String = "Stage1st",
        cookieStorage: HTTPCookieStorage = HTTPCookieStorage.shared,
        settings: Stage1stSettings = Stage1stSettings(defaults: UserDefaults.standard),
        reachability: Reachability = Reachability.forInternetConnection()
    ) {
        self.forumName = forumName
        self.cookieStorage = cookieStorage
        self.settings = settings
        self.reachability = reachability
        reachability.startNotifier()

        colorManager = ColorManager(nightMode: settings.nightMode.value)
        eventTracker = S1EventTracker()
        cacheDatabaseManager = CacheDatabaseManager(path: Environment.cacheDatabasePath())

        if let cachedServerAddress = cacheDatabaseManager.serverAddress(), cachedServerAddress.isPrefered(to: ServerAddress.default) {
            serverAddress = cachedServerAddress
        } else {
            serverAddress = ServerAddress.default
        }

        apiService = DiscuzClient(baseURL: serverAddress.api)
        networkManager = S1NetworkManager(baseURL: serverAddress.page)
        webKitImageDownloader = WebKitImageDownloader()

        databaseManager = DatabaseManager.sharedInstance()
        cloudkitManager = CloudKitManager(cloudkitContainer: CKContainer.default(), databaseManager: databaseManager)
        databaseAdapter = S1YapDatabaseAdapter(database: databaseManager)

        dataCenter = DataCenter(
            apiManager: apiService,
            networkManager: networkManager,
            databaseManager: databaseManager,
            cacheDatabaseManager: cacheDatabaseManager
        )
    }

    static func databasePath() -> String {
        let databaseName = "Stage1stYap.sqlite"
        let baseURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let databaseURL = baseURL.appendingPathComponent(databaseName, isDirectory: false)
        return databaseURL.standardizedFileURL.path
    }

    static func cacheDatabasePath() -> String {
        let databaseName = "Cache.sqlite"
        let baseURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheDatabaseURL = baseURL.appendingPathComponent(databaseName, isDirectory: false)
        return cacheDatabaseURL.standardizedFileURL.path
    }
}
