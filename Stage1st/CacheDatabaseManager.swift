//
//  CacheDatabaseManager.swift
//  Stage1st
//
//  Created by Zheng Li on 9/19/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import YapDatabase
import CocoaLumberjack

private let collectionPageFloors = "topicFloors"
private let collectionFloorIDs = "floorIDs"
private let collectionMahjongFace = "mahjongFace"
private let metadataLastUsed = "lastUsed"

class CacheDatabaseManager: NSObject {
    static let shared = CacheDatabaseManager()

    let cacheDatabase: YapDatabase
    let readConnection: YapDatabaseConnection
    let backgroundWriteConnection: YapDatabaseConnection

    override init() {
        let documentsDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let path = documentsDirectory.appendingPathComponent("Cache.sqlite")
        self.cacheDatabase = YapDatabase(path: path.absoluteString)
        self.readConnection = self.cacheDatabase.newConnection()
        self.backgroundWriteConnection = self.cacheDatabase.newConnection()

        super.init()
    }

    func set(floors: [Floor], topicID: Int, page: Int, completion: (() -> Void)?) {
        let key = self._key(for: topicID, page: page)

        self.backgroundWriteConnection.asyncReadWrite({ (transaction) in

            for floor in floors {
                transaction.setObject(key, forKey: "\(floor.ID)", inCollection: collectionFloorIDs)
            }

            transaction.setObject(floors, forKey: key, inCollection: collectionPageFloors, withMetadata: [metadataLastUsed: Date()])

        }, completionBlock: {
            DDLogVerbose("cached \(key)")
            completion?()
        })
    }

    func floors(in topicID: Int, page: Int) -> [Floor]? {
        return nil
    }

    func hasFloors(in topicID: Int, page: Int) -> Bool {
        return false
    }

    func removeFloors(in topicID: Int, page: Int) {

    }
}

extension CacheDatabaseManager {
    func floor(ID: Int) -> Floor? {
        return nil
    }
}

extension CacheDatabaseManager {
    func removeFloors(lastUsedBefore date: Date) {

    }
}

extension CacheDatabaseManager {
    func set(mahjongFaceHistory: [[Any]]) {
        // Array<(String, String, URL)>
    }

    func mahjongFaceHistory() -> [[Any]]? {
        return nil
    }
}

extension CacheDatabaseManager {
    func _key(for topicID: Int, page: Int) -> String {
        return "\(topicID):\(page)"
    }
}
