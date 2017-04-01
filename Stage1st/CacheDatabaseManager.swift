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
private let collectionServerAddress = "serverAddress"
private let metadataLastUsed = "lastUsed"
private let keyMahjongFaceHistory = "mahjongFaceHistory"
private let keyServerAddress = "serverAddress"

class CacheDatabaseManager: NSObject {
    let cacheDatabase: YapDatabase
    let readConnection: YapDatabaseConnection
    let backgroundWriteConnection: YapDatabaseConnection

    static var shared = CacheDatabaseManager(path: Environment.cacheDatabasePath())

    init(path: String) {
        cacheDatabase = YapDatabase(path: path)
        readConnection = cacheDatabase.newConnection()
        backgroundWriteConnection = cacheDatabase.newConnection()

        super.init()
    }

    func set(floors: [Floor], topicID: Int, page: Int, completion: (() -> Void)?) {
        let key = _key(for: topicID, page: page)

        backgroundWriteConnection.asyncReadWrite({ transaction in

            for floor in floors {
                transaction.setObject(key, forKey: "\(floor.ID)", inCollection: collectionFloorIDs)
            }

            transaction.setObject(floors, forKey: key, inCollection: collectionPageFloors, withMetadata: [metadataLastUsed: Date()])

        }, completionBlock: {
            DDLogVerbose("[CacheDatabase] finish cache for key: \(key)")
            completion?()
        })
    }

    func floors(in topicID: Int, page: Int) -> [Floor]? {
        let key = _key(for: topicID, page: page)
        var result: [Floor]?
        readConnection.read { transaction in
            result = transaction.object(forKey: key, inCollection: collectionPageFloors) as? [Floor]
        }
        backgroundWriteConnection.asyncReadWrite { transaction in
            if let originMetadata = transaction.metadata(forKey: key, inCollection: collectionPageFloors) as? [String: Any] {
                var mutableOriginMetadata = originMetadata
                mutableOriginMetadata[metadataLastUsed] = Date()
                transaction.replaceMetadata(mutableOriginMetadata, forKey: key, inCollection: collectionPageFloors)
            } else {
                transaction.replaceMetadata([metadataLastUsed: Date()], forKey: key, inCollection: collectionPageFloors)
            }
        }
        return result
    }

    func hasFloors(in topicID: Int, page: Int) -> Bool {
        let key = _key(for: topicID, page: page)
        var hasFloors: Bool = false
        readConnection.read { transaction in
            if let _ = transaction.object(forKey: key, inCollection: collectionPageFloors) as? [Floor] {
                hasFloors = true
            }
        }
        return hasFloors
    }

    func removeFloors(in topicID: Int, page: Int) {
        let key = _key(for: topicID, page: page)
        backgroundWriteConnection.readWrite { transaction in
            transaction.removeObject(forKey: key, inCollection: collectionPageFloors)
        }
    }
}

extension CacheDatabaseManager {
    func floor(ID: Int) -> Floor? {
        var floor: Floor?
        readConnection.read { transaction in
            guard
                let key = transaction.object(forKey: "\(ID)", inCollection: collectionFloorIDs) as? String,
                let floors = transaction.object(forKey: key, inCollection: collectionPageFloors) as? [Floor] else {
                DDLogWarn("Failed to find floor(ID: \(ID)) in cache database due to index or cache not exist.")
                return
            }
            floor = floors.first(where: { (aFloor) -> Bool in
                aFloor.ID == ID
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
        self.backgroundWriteConnection.readWrite { transaction in
            transaction.removeAllObjects(inCollection: collectionPageFloors)
            transaction.removeAllObjects(inCollection: collectionFloorIDs)
        }
    }

    /// Note: this operation will leave tings in collectionFloors (i.e. the index) uncleaned. make sure to clean them.
    func removeFloors(lastUsedBefore date: Date) {
        self.backgroundWriteConnection.readWrite { transaction in
            var keysToRemove = [String]()
            transaction.enumerateKeysAndMetadata(inCollection: collectionPageFloors, using: { key, metadata, _ in
                guard
                    let metadata = metadata as? [String: Any],
                    let lastUsedDate = metadata[metadataLastUsed] as? Date else {
                    DDLogWarn("key\(key) do not have valid metadata. skipped.")
                    return
                }

                if date.timeIntervalSince(lastUsedDate) > 0 {
                    keysToRemove.append(key)
                }
            })

            DDLogInfo("Keys to remove from floor cache: \(keysToRemove)")
            for key in keysToRemove {
                transaction.removeObject(forKey: key, inCollection: collectionPageFloors)
            }
        }
    }

    func cleanInvalidFloorsID() {
        self.backgroundWriteConnection.readWrite { transaction in
            var floorIDsToRemove = [String]()
            transaction.enumerateKeysAndObjects(inCollection: collectionFloorIDs, using: { floorID, key, _ in
                guard let keyString = key as? String else {
                    DDLogWarn("floorID \(floorID) index to \(key) which is not a string key as expected.")
                    return
                }
                if let _ = transaction.object(forKey: keyString, inCollection: collectionPageFloors) as? [Floor] {
                    // Nothing to do
                } else {
                    floorIDsToRemove.append(floorID)
                }
            })

            for floorID in floorIDsToRemove {
                transaction.removeObject(forKey: floorID, inCollection: collectionFloorIDs)
            }
        }
    }
}

// MARK: - Mahjong Face History
extension CacheDatabaseManager {
    func set(mahjongFaceHistory: [MahjongFaceItem]) {
        self.backgroundWriteConnection.asyncReadWrite { transaction in
            transaction.setObject(mahjongFaceHistory, forKey: keyMahjongFaceHistory, inCollection: collectionMahjongFace)
        }
    }

    func mahjongFaceHistory() -> [MahjongFaceItem] {
        var mahjongFaceHistory: [MahjongFaceItem]?
        self.readConnection.read { transaction in
            mahjongFaceHistory = transaction.object(forKey: keyMahjongFaceHistory, inCollection: collectionMahjongFace) as? [MahjongFaceItem]
        }
        return mahjongFaceHistory ?? [MahjongFaceItem]()
    }
}

// MARK: - Server Address
extension CacheDatabaseManager {
    func set(serverAddress: ServerAddress) {
        self.backgroundWriteConnection.readWrite { transaction in
            transaction.setObject(serverAddress, forKey: keyServerAddress, inCollection: collectionServerAddress)
        }
    }

    func serverAddress() -> ServerAddress? {
        var serverAddress: ServerAddress?
        self.readConnection.read { transaction in
            serverAddress = transaction.object(forKey: keyServerAddress, inCollection: collectionServerAddress) as? ServerAddress
        }
        return serverAddress
    }
}

// MARK: - Helper
private extension CacheDatabaseManager {
    func _key(for topicID: Int, page: Int) -> String {
        return "\(topicID):\(page)"
    }
}
