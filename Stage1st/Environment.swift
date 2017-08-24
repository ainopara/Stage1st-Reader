//
//  Environment.swift
//  Stage1st
//
//  Created by Zheng Li on 13/03/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation

@objcMembers
class Environment: NSObject {
    let forumName: String
    let serverAddress: ServerAddress
    let cookieStorage: HTTPCookieStorage
    let apiService: DiscuzClient
    let networkManager: S1NetworkManager
    let urlSessionManager: URLSessionManager
    let databaseManager: DatabaseManager
    let cacheDatabaseManager: CacheDatabaseManager

    let databaseAdapter: S1YapDatabaseAdapter
    let dataCenter: DataCenter

    init(forumName: String = "Stage1st",
         cookieStorage: HTTPCookieStorage = HTTPCookieStorage.shared) {

        self.forumName = forumName
        self.cookieStorage = cookieStorage

        cacheDatabaseManager = CacheDatabaseManager.shared

        if let cachedServerAddress = cacheDatabaseManager.serverAddress(), cachedServerAddress.isPrefered(to: ServerAddress.default) {
            serverAddress = cachedServerAddress
        } else {
            serverAddress = ServerAddress.default
        }

        apiService = DiscuzClient(baseURL: serverAddress.api)
        networkManager = S1NetworkManager(baseURL: serverAddress.page)
        urlSessionManager = URLSessionManager()

        databaseManager = DatabaseManager.sharedInstance()
        databaseAdapter = S1YapDatabaseAdapter(database: databaseManager)

        dataCenter = DataCenter(apiManager: apiService,
                                networkManager: networkManager,
                                databaseManager: databaseManager,
                                cacheDatabaseManager: cacheDatabaseManager)
    }

    static func cacheDatabasePath() -> String {
        let documentsDirectoryURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheDatabasePath = documentsDirectoryURL.appendingPathComponent("Cache.sqlite").standardizedFileURL.path
        return cacheDatabasePath
    }
}
