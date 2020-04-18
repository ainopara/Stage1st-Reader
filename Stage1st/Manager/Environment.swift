//
//  Environment.swift
//  Stage1st
//
//  Created by Zheng Li on 13/03/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation
import Reachability
import Combine

@objcMembers
class AppEnvironment: NSObject {
    private static var stack: [Environment] = [Environment()]

    static var current: Environment {
        return stack.last!
    }

    static func replaceCurrent(with newEnvironment: Environment) {
        stack.append(newEnvironment)
        stack.remove(at: stack.count - 2)
    }
}

@objcMembers
class Environment: NSObject {

    let forumName: String
    let serverAddress: ServerAddress
    let cookieStorage: HTTPCookieStorage
    let settings: Stage1stSettings
    let reachability: Reachability
    let apiService: DiscuzClient
    let webKitImageDownloader: WebKitImageDownloader
    let databaseManager: DatabaseManager
    let cloudkitManager: CloudKitManager
    let cacheDatabaseManager: CacheDatabaseManager
    let colorManager: ColorManager
    let eventTracker: EventTracker

    let databaseAdapter: S1YapDatabaseAdapter
    let dataCenter: DataCenter

    private var bag = Set<AnyCancellable>()

    init(
        forumName: String = "Stage1st",
        databaseName: String = "Stage1stYap.sqlite",
        cacheDatabaseName: String = "Cache.sqlite",
        sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.af.default,
        cookieStorage: HTTPCookieStorage = HTTPCookieStorage.shared,
        settings: Stage1stSettings = Stage1stSettings(defaults: UserDefaults.standard),
        reachability: Reachability = Reachability.forInternetConnection()
    ) {
        self.forumName = forumName
        self.cookieStorage = cookieStorage
        self.settings = settings
        self.reachability = reachability
        reachability.startNotifier()

        let overrideNightMode = CurrentValueSubject<Bool?, Never>(nil)

        settings.manualControlInterfaceStyle.combineLatest(settings.nightMode)
            .map { (manualControlInterfaceStyle, isNightMode) -> Bool? in
                if manualControlInterfaceStyle {
                    return isNightMode
                } else {
                    return nil
                }
            }
            .subscribe(overrideNightMode)
            .store(in: &bag)

        colorManager = ColorManager(overrideNightMode: overrideNightMode)
        eventTracker = S1EventTracker()
        cacheDatabaseManager = CacheDatabaseManager(path: Self.cacheDatabasePath(with: cacheDatabaseName))

        if let cachedServerAddress = cacheDatabaseManager.serverAddress(), cachedServerAddress.isPrefered(to: ServerAddress.default) {
            serverAddress = cachedServerAddress
        } else {
            serverAddress = ServerAddress.default
        }

        apiService = DiscuzClient(baseURL: serverAddress.api, configuration: sessionConfiguration)
        webKitImageDownloader = WebKitImageDownloader(name: "ImageDownloader")

        databaseManager = DatabaseManager(name: databaseName)
        cloudkitManager = CloudKitManager(cloudkitContainer: CKContainer.default(), databaseManager: databaseManager)
        databaseAdapter = S1YapDatabaseAdapter(database: databaseManager)

        dataCenter = DataCenter(
            apiManager: apiService,
            databaseManager: databaseManager,
            cacheDatabaseManager: cacheDatabaseManager
        )
    }

    static func databasePath(with name: String) -> String {
        return Self.filePath(with: name)
    }

    static func cacheDatabasePath(with name: String) -> String {
        return filePath(with: name)
    }

    static func filePath(with name: String) -> String {
        let baseURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let databaseURL = baseURL.appendingPathComponent(name, isDirectory: false)
        return databaseURL.standardizedFileURL.path
    }
}
