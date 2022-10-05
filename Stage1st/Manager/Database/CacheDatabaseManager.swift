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
private let keyMahjongFaceHistoryV2 = "mahjongFaceHistoryV2"
private let keyMahjongFaceHistoryV3 = "mahjongFaceHistoryV3"
private let keyServerAddress = "serverAddress"

class CacheDatabaseManager: NSObject {
    let cacheDatabase: YapDatabase
    let readConnection: YapDatabaseConnection
    let backgroundWriteConnection: YapDatabaseConnection

    init(path: String) {
        let serializer: YapDatabaseSerializer = { (collection, key, object) in
            switch collection {
            case collectionPageFloors:
                return (try? JSONEncoder().encode(object as! [Floor])) ?? Data()
            default:
                return NSKeyedArchiver.archivedData(withRootObject: object)
            }
        }

        let deserializer: YapDatabaseDeserializer = { (collection, key, data) in
            switch collection {
            case collectionPageFloors:
                return (try? JSONDecoder().decode([Floor].self, from: data)) as Any
            default:
                return (data.count > 0 ? NSKeyedUnarchiver.unarchiveObject(with: data) : nil) as Any
            }
        }

        let instance = YapDatabase(
            path: path,
            objectSerializer: serializer,
            objectDeserializer: deserializer,
            metadataSerializer: YapDatabase.defaultSerializer(),
            metadataDeserializer: YapDatabase.defaultDeserializer()
        )

        if let instance = instance {
            cacheDatabase = instance
        } else {
            try! FileManager.default.removeItem(at: URL(fileURLWithPath: path))
            cacheDatabase = YapDatabase(
                path: path,
                objectSerializer: serializer,
                objectDeserializer: deserializer,
                metadataSerializer: YapDatabase.defaultSerializer(),
                metadataDeserializer: YapDatabase.defaultDeserializer()
            )!
        }

        readConnection = cacheDatabase.newConnection()
        backgroundWriteConnection = cacheDatabase.newConnection()

        super.init()
    }

    func set(floors: [Floor], topicID: Int, page: Int, completion: (() -> Void)?) {
        let key = _key(for: topicID, page: page)

        backgroundWriteConnection.asyncReadWrite({ transaction in

            for floor in floors {
                transaction.setObject(key, forKey: "\(floor.id)", inCollection: collectionFloorIDs)
            }

            transaction.setObject(floors, forKey: key, inCollection: collectionPageFloors, withMetadata: [metadataLastUsed: Date()])

        }, completionBlock: {
            S1LogVerbose("[CacheDatabase] finish cache for key: \(key)")
            completion?()
        })
    }

    func set(floors: [Floor], topicID: Int, page: Int) async {
        return await withCheckedContinuation { continuation in
            set(floors: floors, topicID: topicID, page: page) { continuation.resume(returning: ()) }
        }
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
            if transaction.object(forKey: key, inCollection: collectionPageFloors) as? [Floor] != nil {
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
    func floor(id: Int) -> Floor? {
        var floor: Floor?
        readConnection.read { transaction in
            guard
                let key = transaction.object(forKey: "\(id)", inCollection: collectionFloorIDs) as? String,
                let floors = transaction.object(forKey: key, inCollection: collectionPageFloors) as? [Floor] else {
                S1LogWarn("Failed to find floor(id: \(id)) in cache database due to index or cache not exist.")
                return
            }
            floor = floors.first(where: { (aFloor) -> Bool in
                aFloor.id == id
            })
            if floor == nil {
                S1LogWarn("Failed to find floor(id: \(id)) in cache database due to floor not in indexed batch.")
            }
        }
        return floor
    }
}

// MARK: - Cleaning
extension CacheDatabaseManager {

    func removeAllData() {
        backgroundWriteConnection.readWrite { transaction in
            transaction.removeAllObjectsInAllCollections()
        }
    }

    func removeAllCaches() {
        backgroundWriteConnection.readWrite { transaction in
            transaction.removeAllObjects(inCollection: collectionPageFloors)
            transaction.removeAllObjects(inCollection: collectionFloorIDs)
        }
    }

    /// Note: this operation will leave tings in collectionFloors (i.e. the index) uncleaned. make sure to clean them.
    func removeFloors(lastUsedBefore date: Date) {
        backgroundWriteConnection.readWrite { transaction in
            var keysToRemove = [String]()
            transaction.enumerateKeysAndMetadata(inCollection: collectionPageFloors, using: { key, metadata, _ in
                guard
                    let metadata = metadata as? [String: Any],
                    let lastUsedDate = metadata[metadataLastUsed] as? Date else {
                    S1LogWarn("key\(key) do not have valid metadata. skipped.")
                    return
                }

                if date.timeIntervalSince(lastUsedDate) > 0 {
                    keysToRemove.append(key)
                }
            })

            S1LogInfo("Keys to remove from floor cache: \(keysToRemove)")
            for key in keysToRemove {
                transaction.removeObject(forKey: key, inCollection: collectionPageFloors)
            }
        }
    }

    func cleanInvalidFloorsID() {
        backgroundWriteConnection.readWrite { transaction in
            var floorIDsToRemove = [String]()
            transaction.enumerateKeysAndObjects(inCollection: collectionFloorIDs, using: { floorID, key, _ in
                guard let keyString = key as? String else {
                    S1LogWarn("floorID \(floorID) index to \(key) which is not a string key as expected.")
                    return
                }
                if transaction.object(forKey: keyString, inCollection: collectionPageFloors) as? [Floor] == nil {
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
    func set(mahjongFaceHistoryV2 history: [MahjongFaceItem]) {
        backgroundWriteConnection.asyncReadWrite { transaction in
            transaction.setObject(history, forKey: keyMahjongFaceHistoryV2, inCollection: collectionMahjongFace)
        }
    }

    func mahjongFaceHistoryV2() -> [MahjongFaceItem] {
        var mahjongFaceHistory: [MahjongFaceItem]?
        readConnection.read { transaction in
            mahjongFaceHistory = transaction.object(forKey: keyMahjongFaceHistoryV2, inCollection: collectionMahjongFace) as? [MahjongFaceItem]
        }
        return mahjongFaceHistory ?? [MahjongFaceItem]()
    }

    func set(mahjongFaceHistory history: [MahjongFaceInputView.HistoryItem]) {
        let jsonData = try! JSONEncoder().encode(history)
        backgroundWriteConnection.asyncReadWrite { transaction in
            transaction.setObject(jsonData, forKey: keyMahjongFaceHistoryV3, inCollection: collectionMahjongFace)
        }
    }

    func mahjongFaceHistory() -> [MahjongFaceInputView.HistoryItem] {
        var data: Data?
        readConnection.read { transaction in
            data = transaction.object(forKey: keyMahjongFaceHistoryV3, inCollection: collectionMahjongFace) as? Data
        }

        if
            let data = data,
            let model = try? JSONDecoder().decode([MahjongFaceInputView.HistoryItem].self, from: data) {
            return model
        } else {
            return [MahjongFaceInputView.HistoryItem]()
        }
    }
}

// MARK: - Server Address
extension CacheDatabaseManager {
    func set(serverAddress: ServerAddress) {
        backgroundWriteConnection.readWrite { transaction in
            transaction.setObject(serverAddress, forKey: keyServerAddress, inCollection: collectionServerAddress)
        }
    }

    func serverAddress() -> ServerAddress? {
        var serverAddress: ServerAddress?
        readConnection.read { transaction in
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
