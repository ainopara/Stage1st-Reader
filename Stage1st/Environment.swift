//
//  Environment.swift
//  Stage1st
//
//  Created by Zheng Li on 13/03/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation

class Environment: NSObject {
    let forumName: String
    let serverAddress: ServerAddress
    let cookieStorage: HTTPCookieStorage
    let apiService: DiscuzClient
    let databaseManager: DatabaseManager
    let cacheDatabaseManager: CacheDatabaseManager

    let databaseAdapter: S1YapDatabaseAdapter
    let dataCenter: DataCenter

    var baseURL: String {
        return serverAddress.main
    }

    init(forumName: String = "Stage1st",
         cookieStorage: HTTPCookieStorage = HTTPCookieStorage.shared) {

        self.forumName = forumName
        self.cookieStorage = cookieStorage

        cacheDatabaseManager = CacheDatabaseManager.shared
        self.serverAddress = cacheDatabaseManager.serverAddress() ?? ServerAddress.default
        apiService = DiscuzClient(baseURL: serverAddress.main)

        databaseManager = DatabaseManager.sharedInstance()
        databaseAdapter = S1YapDatabaseAdapter(database: databaseManager)
        dataCenter = DataCenter(client: apiService,
                                databaseManager: databaseManager,
                                cacheDatabaseManager: cacheDatabaseManager)
    }

    static func cacheDatabasePath() -> String {
        let documentsDirectoryURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheDatabasePath = documentsDirectoryURL.appendingPathComponent("Cache.sqlite").standardizedFileURL.path
        return cacheDatabasePath
    }
}
