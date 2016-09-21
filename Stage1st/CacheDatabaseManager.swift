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
        let key = self._key(for: topicID, page: page)
        var result: [Floor]? = nil
        self.readConnection.read { (transaction) in
            result = transaction.object(forKey: key, inCollection: collectionPageFloors) as? [Floor]
        }
        self.backgroundWriteConnection.asyncReadWrite { (transaction) in
            if let originMetadata = transaction.metadata(forKey: key, inCollection: collectionPageFloors) as? [String: Date] {
                var mutableOriginMetadata = originMetadata
                mutableOriginMetadata[metadataLastUsed] = Date()
                transaction.replaceMetadata(mutableOriginMetadata, forKey: key, inCollection: collectionPageFloors)
            } else {
                transaction.replaceMetadata([metadataLastUsed: Date()], forKey: key, inCollection: collectionPageFloors)
            }
        }
        return result;
    }

    func hasFloors(in topicID: Int, page: Int) -> Bool {
        let key = self._key(for: topicID, page: page)
        var hasFloors: Bool = false
        self.readConnection.read { (transaction) in
            hasFloors = transaction.hasObject(forKey: key, inCollection: collectionPageFloors)
        }
        return hasFloors
    }

    func removeFloors(in topicID: Int, page: Int) {
        let key = self._key(for: topicID, page: page)
        self.backgroundWriteConnection.readWrite { (transaction) in
            transaction.removeObject(forKey: key, inCollection: collectionPageFloors)
        }
    }
}

extension CacheDatabaseManager {
    func floor(ID: Int) -> Floor? {
        var floor: Floor? = nil;
        self.readConnection.read { (transaction) in
            guard
                let key = transaction.object(forKey: "\(ID)", inCollection: collectionFloorIDs) as? String,
                let floors = transaction.object(forKey: key, inCollection: collectionPageFloors) as? [Floor]  else {
                DDLogWarn("Failed to find floor(ID: \(ID)) in cache database due to index or cache not exist.")
                return;
            }
            floor = floors.first(where: { (aFloor) -> Bool in
                return aFloor.ID == ID
            })
            if floor == nil {
                DDLogWarn("Failed to find floor(ID: \(ID)) in cache database due to floor not in indexed batch.")
            }
        }
        return floor
    }
}

// MARK: - Cleaning
extension CacheDatabaseManager {
    func removeAllCaches() {
        self.backgroundWriteConnection.readWrite { (transaction) in
            transaction.removeAllObjects(inCollection: collectionPageFloors)
            transaction.removeAllObjects(inCollection: collectionFloorIDs)
        }
    }

    func removeFloors(lastUsedBefore date: Date) {
        self.backgroundWriteConnection.readWrite { (transaction) in
            transaction.enumerateKeysAndMetadata(inCollection: collectionPageFloors, using: <#T##(String, Any?, UnsafeMutablePointer<ObjCBool>) -> Void#>)
        }
    }
}

// MARK: - Mahjong Face History
extension CacheDatabaseManager {
    func set(mahjongFaceHistory: [[Any]]) {
        // Array<(String, String, URL)>
    }

    func mahjongFaceHistory() -> [[Any]]? {
        return nil
    }
}

// MARK: - Helper
extension CacheDatabaseManager {
    func _key(for topicID: Int, page: Int) -> String {
        return "\(topicID):\(page)"
    }
}
