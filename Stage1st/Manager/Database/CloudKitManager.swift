//
//  CloudKitManager.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/4/16.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import CloudKit
import ReactiveSwift
import YapDatabase
import CocoaLumberjack

private let cloudkitZoneName = "zone1"

private let cloudKitCollection = "cloudKit"

private let cloudKitManagerVersionKey = "CloudKitManagerVersion"
private let hasZoneKey = "hasZone"
private let hasZoneSubscriptionKey = "hasZoneSubscription"
private let serverChangeTokenKey = "serverChangeToken"

private let cloudKitManagerVersion = 1

class CloudKitManager1 {
    let cloudkitContainer: CKContainer
    let databaseConnection: YapDatabaseConnection

    private(set) var state: MutableProperty<State> = MutableProperty(.waitingSetupTriggered)
    private(set) var accountStatus: MutableProperty<CKAccountStatus> = MutableProperty(.couldNotDetermine)

    enum State {
        case waitingSetupTriggered
        case migrating
        case createZone
        case createZoneError(Error)
        case createZoneSubscription
        case createZoneSubscriptionError(Error)
        case fetchRecordChanges
        case fetchRecordChangesError(Error)
        case uploading
        case idle
        case recovering
        case halt
    }

    init(cloudkitContainer: CKContainer, databaseConnection: YapDatabaseConnection) {
        self.cloudkitContainer = cloudkitContainer
        self.databaseConnection = databaseConnection

        NotificationCenter.default.reactive.notifications(forName: .CKAccountChanged).producer.startWithValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.cloudkitContainer.accountStatus { [weak self] (accountStatus, error) in
                guard let strongSelf = self else { return }
                strongSelf.accountStatus.value = accountStatus

                if let error = error {
                    S1LogWarn("CloudKit Account Change Fetch Error: \(error)")
                }
            }
        }

        state.producer.startWithValues { [weak self] (state) in
            guard let strongSelf = self else { return }

            switch state {
            case .waitingSetupTriggered:
                break
            case .migrating:
                strongSelf.migrateIfNecessary()
            case .createZone:
                strongSelf.createZoneIfNecessary()
            case let .createZoneError(error):
                strongSelf.handleCreateZoneError(error)
            case .createZoneSubscription:
                strongSelf.createZoneSubscriptionIfNecessary()
            case let .createZoneSubscriptionError(error):
                strongSelf.handleCreateZoneSubscriptionError(error)
            case .fetchRecordChanges:
                strongSelf.fetchRecordChange { (fetchResult) in
                    S1LogDebug("fetch finished with result: \(fetchResult)")
                }
            default:
                break
            }
        }

        // Debug
        state.producer.combinePrevious().startWithValues { (previous, current) in
            S1LogDebug("State: \(previous) -> \(current)")
        }

        accountStatus.producer.combinePrevious().startWithValues { (previous, current) in
            S1LogDebug("AccountStatus: \(previous) -> \(current)")
        }
    }

    func setup() {
        state.value = .migrating
    }

    func migrateIfNecessary() {
        defer { state.value = .createZone }

        var oldVersion: Int = 0
        databaseConnection.read { (transaction) in
            if let value = transaction.object(forKey: cloudKitManagerVersionKey, inCollection: cloudKitCollection) as? Int {
                oldVersion = value
            }
        }

        guard oldVersion < cloudKitManagerVersion else {
            return
        }

        if oldVersion < 1 {
            databaseConnection.readWrite { (transaction) in
                transaction.removeObject(forKey: hasZoneSubscriptionKey, inCollection: cloudKitCollection)
                transaction.setObject(1, forKey: cloudKitManagerVersionKey, inCollection: cloudKitCollection)
            }
        }
    }

    func createZoneIfNecessary() {
        var needsCreateZone: Bool = true
        databaseConnection.read { (transaction) in
            if transaction.hasObject(forKey: hasZoneKey, inCollection: cloudKitCollection) {
                needsCreateZone = false
            }
        }

        guard needsCreateZone else {
            state.value = .createZoneSubscription
            return
        }

        /// Typically, default zones do not support any special capabilities. Custom zones in a private database normally support all options.
        /// We create a custom zone to get the capability of fetch record changes.
        let recordZone = CKRecordZone(zoneName: cloudkitZoneName)
        let modifyRecordZonesOperation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone], recordZoneIDsToDelete: nil)
        modifyRecordZonesOperation.modifyRecordZonesCompletionBlock = { [weak self] (savedRecordZones, deletedRecordZoneIDs, operationError) in
            guard let strongSelf = self else { return }

            if let operationError = operationError {
                strongSelf.state.value = .createZoneError(operationError)
                return
            }

            S1LogDebug("Successfully created zones: \(String(describing: savedRecordZones))")

            strongSelf.databaseConnection.readWrite({ (transaction) in
                transaction.setObject(true, forKey: hasZoneKey, inCollection: cloudKitCollection)
            })

            strongSelf.state.value = .createZoneSubscription
        }

        cloudkitContainer.privateCloudDatabase.add(modifyRecordZonesOperation)
    }

    func handleCreateZoneError(_ error: Error) {
        S1LogWarn("Error creating zone: \(error)")
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                S1LogWarn("Account not authenticated.")
            case .partialFailure:
                S1LogWarn("Partial failure.")
            default:
                S1LogWarn("Other error case.")
            }
        } else {
            S1LogWarn("Other error domain.")
        }
    }

    func createZoneSubscriptionIfNecessary() {
        let recordZoneID = CKRecordZoneID(zoneName: cloudkitZoneName, ownerName: CKCurrentUserDefaultName)
        let subscription = CKRecordZoneSubscription(zoneID: recordZoneID, subscriptionID: cloudkitZoneName)
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let modifySubscriptionsOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        modifySubscriptionsOperation.modifySubscriptionsCompletionBlock = { [weak self] (savedSubscriptions, deletedSubscriptionIDs, operationError) in
            guard let strongSelf = self else { return }

            if let operationError = operationError {
                strongSelf.state.value = .createZoneSubscriptionError(operationError)
                return
            }

            S1LogDebug("Successfully created subscription: \(String(describing: savedSubscriptions))")

            strongSelf.databaseConnection.readWrite({ (transaction) in
                transaction.setObject(true, forKey: hasZoneSubscriptionKey, inCollection: cloudKitCollection)
            })

            strongSelf.state.value = .fetchRecordChanges
        }

        cloudkitContainer.privateCloudDatabase.add(modifySubscriptionsOperation)
    }

    func handleCreateZoneSubscriptionError(_ error: Error) {
        S1LogWarn("Error creating zone subscription: \(error)")

    }

    func fetchRecordChange(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        var previousChangeToken: CKServerChangeToken? = nil

        databaseConnection.read { (transaction) in
            previousChangeToken = transaction.object(forKey: serverChangeTokenKey, inCollection: cloudKitCollection) as? CKServerChangeToken
        }

        fetchRecordChange(with: previousChangeToken, completion: completion)
    }

    func fetchRecordChange(with previousServerChangeToken: CKServerChangeToken?, completion: @escaping (UIBackgroundFetchResult) -> Void) {
        let recordZoneID = CKRecordZoneID(zoneName: cloudkitZoneName, ownerName: CKCurrentUserDefaultName)
        let fetchOptions = CKFetchRecordZoneChangesOptions()
        fetchOptions.previousServerChangeToken = previousServerChangeToken

        let fetchOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [recordZoneID], optionsByRecordZoneID: [recordZoneID: fetchOptions])
        var deletedRecordIDs = [CKRecordID]()
        var changedRecords = [CKRecord]()

        fetchOperation.recordWithIDWasDeletedBlock = { (recordID, recordType) in
            deletedRecordIDs.append(recordID)
        }

        fetchOperation.recordChangedBlock = { record in
            changedRecords.append(record)
        }

        fetchOperation.recordZoneChangeTokensUpdatedBlock = { [weak self] (recordZoneID, serverChangeToken, clientChangeTokenData) in
            S1LogDebug("CKFetchRecordChangesOperation: serverChangeToken update: \(String(describing: serverChangeToken))")
            S1LogDebug("deleted: \(deletedRecordIDs.count) changed: \(changedRecords.count)")
            guard let strongSelf = self else { return }

            let hasChange = deletedRecordIDs.count > 0 || changedRecords.count > 0

            if !hasChange {
                // We do not have any change in cloud. Just save the new server change token
                strongSelf.databaseConnection.readWrite({ (transaction) in
                    transaction.setObject(serverChangeToken, forKey: serverChangeTokenKey, inCollection: cloudKitCollection)
                })
            } else {
                strongSelf.databaseConnection.readWrite({ (transaction) in
                    transaction.deleteKeysAssociatedWithRecordIDs(deletedRecordIDs)
                    transaction.updateDatabaseWithRecords(changedRecords)
                    transaction.setObject(serverChangeToken, forKey: serverChangeTokenKey, inCollection: cloudKitCollection)
                })
                deletedRecordIDs.removeAll()
                changedRecords.removeAll()
            }
        }

        fetchOperation.recordZoneFetchCompletionBlock = { [weak self] (recordZoneID, serverChangeToken, clientChangeTokenData, moreComing, recordZoneError) in
            S1LogDebug("CKFetchRecordChangesOperation: serverChangeToken final: \(String(describing: serverChangeToken))")
            S1LogDebug("deleted: \(deletedRecordIDs.count) changed: \(changedRecords.count)")

            guard let strongSelf = self else { return }

            if let recordZoneError = recordZoneError {
                S1LogError("recordZoneError: \(recordZoneError)")
                completion(.failed)
                return
            }

            let hasChange = deletedRecordIDs.count > 0 || changedRecords.count > 0

            if !hasChange {
                // We do not have any change in cloud. Just save the new server change token
                strongSelf.databaseConnection.readWrite({ (transaction) in
                    transaction.setObject(serverChangeToken, forKey: serverChangeTokenKey, inCollection: cloudKitCollection)
                })

                completion(.noData)
            } else {
                strongSelf.databaseConnection.readWrite({ (transaction) in
                    transaction.deleteKeysAssociatedWithRecordIDs(deletedRecordIDs)
                    transaction.updateDatabaseWithRecords(changedRecords)
                    transaction.setObject(serverChangeToken, forKey: serverChangeTokenKey, inCollection: cloudKitCollection)
                })

                completion(.newData)
            }
        }

        cloudkitContainer.privateCloudDatabase.add(fetchOperation)
    }
}

private extension YapDatabaseReadWriteTransaction {
    func deleteKeysAssociatedWithRecordIDs(_ recordIDs: [CKRecordID]) {
        guard let cloudkitTransaction = self.ext(Ext_CloudKit) as? YapDatabaseCloudKitTransaction else {
            fatalError()
        }

        for deletedRecordID in recordIDs {
            let collectionKeys = cloudkitTransaction.collectionKeys(for: deletedRecordID, databaseIdentifier: nil)
            for collectionKey in collectionKeys {
                cloudkitTransaction.detachRecord(
                    forKey: collectionKey.key,
                    inCollection: collectionKey.collection,
                    wasRemoteDeletion: true,
                    shouldUploadDeletion: false
                )

                self.removeObject(
                    forKey: collectionKey.key,
                    inCollection: collectionKey.collection
                )
            }
        }
    }

    func updateDatabaseWithRecords(_ records: [CKRecord]) {
        guard let cloudkitTransaction = self.ext(Ext_CloudKit) as? YapDatabaseCloudKitTransaction else {
            fatalError()
        }

        // Ignore unknown record types.
        // These are probably from a future version that this version doesn't support.
        for record in records where record.recordType == "topic" {
            let (recordChangeTag, hasPendingModifications, hasPendingDelete) = cloudkitTransaction.getRecordChangeTag(for: record.recordID, databaseIdentifier: nil)

            switch (recordChangeTag, hasPendingModifications, hasPendingDelete) {
            case (.some(let recordChangeTag), _, _):
                // We have a record change tag in database
                // So the record is currently managed by database
                if recordChangeTag == record.recordChangeTag {
                    // We're the one who changed this record.
                    // So we can quietly ignore it.
                } else {
                    // Other device changed this record, or the record is changed by this device but not the latest change.
                    cloudkitTransaction.merge(record, databaseIdentifier: nil)
                }
            case (.none, true, _):
                // We're not actively managing this record anymore (we deleted/detached it).
                // But there are still previous modifications that are pending upload to server.
                // So this merge is required in order to keep everything running properly (no infinite loops).
                cloudkitTransaction.merge(record, databaseIdentifier: nil)
            case (.none, false, false):
                // This is a new record for us.
                // Add it to our database.
                let topic = S1Topic(record: record)
                let key = topic.topicID.stringValue

                cloudkitTransaction.attach(
                    record,
                    databaseIdentifier: nil,
                    forKey: key,
                    inCollection: Collection_Topics,
                    shouldUploadRecord: false
                )

                self.setObject(
                    topic,
                    forKey: key,
                    inCollection: Collection_Topics
                )
            case (.none, false, true):
                // We're going to delete this record, so do not add it.
                // Nothing to do.
                break
            }
        }
    }
}

private extension YapDatabaseCloudKitTransaction {
    func getRecordChangeTag(for recordID: CKRecordID, databaseIdentifier: String?) -> (String?, Bool, Bool) {
        var recordChangeTag: NSString? = nil
        var hasPendingModifications: ObjCBool = false
        var hasPendingDelete: ObjCBool = false
        self.getRecordChangeTag(&recordChangeTag,
                                hasPendingModifications: &hasPendingModifications,
                                hasPendingDelete: &hasPendingDelete,
                                for: recordID,
                                databaseIdentifier: databaseIdentifier)

        return (
            recordChangeTag.map { $0 as String },
            hasPendingModifications.boolValue,
            hasPendingDelete.boolValue
        )
    }
}
