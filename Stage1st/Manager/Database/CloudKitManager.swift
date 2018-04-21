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

private let Collection_cloudKit = "cloudKit"

private let Key_cloudKitManagerVersion = "CloudKitManagerVersion"
private let Key_hasZone = "hasZone"
private let Key_hasZoneSubscription = "hasZoneSubscription"
private let Key_serverChangeToken = "serverChangeToken"

private let cloudKitManagerVersion = 1

class CloudKitManager1: NSObject {
    let cloudKitContainer: CKContainer
    let databaseConnection: YapDatabaseConnection
    let cloudKitExtension: YapDatabaseCloudKit

    private(set) var state: MutableProperty<State> = MutableProperty(.waitingSetupTriggered)
    private(set) var accountStatus: MutableProperty<CKAccountStatus> = MutableProperty(.couldNotDetermine)

    let queue = DispatchQueue(label: "com.ainopara.stage1st.cloudkit")

    var errors: [S1CloudKitError] = []

    enum State {
        case waitingSetupTriggered
        case migrating
        case createZone
        case createZoneError(Error)
        case createZoneSubscription
        case createZoneSubscriptionError(Error)
        case fetchRecordChanges
        case fetchRecordChangesError(Error)
        case readyForUpload
        case uploadError(Error)
        case halt
    }

    func updateAccountStatus() {
        cloudKitContainer.accountStatus { [weak self] (accountStatus, error) in
            guard let strongSelf = self else { return }
            strongSelf.accountStatus.value = accountStatus

            if let error = error {
                S1LogWarn("CloudKit Account Change Fetch Error: \(error)")
            }
        }
    }

    init(
        cloudkitContainer: CKContainer,
        databaseConnection: YapDatabaseConnection,
        cloudKitExtension: YapDatabaseCloudKit
    ) {
        self.cloudKitContainer = cloudkitContainer
        self.databaseConnection = databaseConnection
        self.cloudKitExtension = cloudKitExtension

        super.init()

        updateAccountStatus()

        NotificationCenter.default.reactive.notifications(forName: .CKAccountChanged).signal.observeValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.updateAccountStatus()
        }

        state.producer.startWithValues { [weak self] (state) in
            guard let strongSelf = self else { return }
            strongSelf.queue.async { [weak self] in
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
                        S1LogDebug("fetch finished with result: \(fetchResult.debugDescription)")
                        switch fetchResult {
                        case .newData, .noData:
                            strongSelf.cloudKitExtension.resume()
                            strongSelf.state.value = .readyForUpload
                        case let .failed(error):
                            strongSelf.state.value = .fetchRecordChangesError(error)
                        }
                    }
                case let .fetchRecordChangesError(error):
                    strongSelf.handleFetchRecordChangesError(error)
                case let .uploadError(error):
                    strongSelf.handleUploadError(error)
                default:
                    break
                }
            }
        }

        // Debug
        state.producer.combinePrevious().startWithValues { (previous, current) in
            S1LogDebug("State: \(previous) -> \(current)")
        }

        accountStatus.producer.combinePrevious().startWithValues { (previous, current) in
            S1LogDebug("AccountStatus: \(previous.debugDescription) -> \(current.debugDescription)")
        }
    }

    func setup() {
        queue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.state.value = .migrating
        }
    }

    @objc func prepareForUnregister() {
        databaseConnection.readWrite { (transaction) in
            transaction.removeObject(forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
            transaction.removeObject(forKey: Key_hasZone, inCollection: Collection_cloudKit)
            transaction.removeObject(forKey: Key_hasZoneSubscription, inCollection: Collection_cloudKit)
        }
    }
}

// MARK: Processes

extension CloudKitManager1 {
    func migrateIfNecessary() {
        defer { state.value = .createZone }

        var oldVersion: Int = 0
        databaseConnection.read { (transaction) in
            if let value = transaction.object(forKey: Key_cloudKitManagerVersion, inCollection: Collection_cloudKit) as? Int {
                oldVersion = value
            }
        }

        guard oldVersion < cloudKitManagerVersion else {
            return
        }

        if oldVersion < 1 {
            databaseConnection.readWrite { (transaction) in
                transaction.removeObject(forKey: Key_hasZoneSubscription, inCollection: Collection_cloudKit)
                transaction.setObject(1, forKey: Key_cloudKitManagerVersion, inCollection: Collection_cloudKit)
            }
        }
    }

    func createZoneIfNecessary() {
        var needsCreateZone: Bool = true
        databaseConnection.read { (transaction) in
            if transaction.hasObject(forKey: Key_hasZone, inCollection: Collection_cloudKit) {
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
                transaction.setObject(true, forKey: Key_hasZone, inCollection: Collection_cloudKit)
            })

            strongSelf.state.value = .createZoneSubscription
        }

        cloudKitContainer.privateCloudDatabase.add(modifyRecordZonesOperation)
    }

    func createZoneSubscriptionIfNecessary() {
        var needsCreateZoneSubscription: Bool = true
        databaseConnection.read { (transaction) in
            if transaction.hasObject(forKey: Key_hasZoneSubscription, inCollection: Collection_cloudKit) {
                needsCreateZoneSubscription = false
            }
        }

        guard needsCreateZoneSubscription else {
            state.value = .fetchRecordChanges
            return
        }

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
                transaction.setObject(true, forKey: Key_hasZoneSubscription, inCollection: Collection_cloudKit)
            })

            strongSelf.state.value = .fetchRecordChanges
        }

        cloudKitContainer.privateCloudDatabase.add(modifySubscriptionsOperation)
    }

    func fetchRecordChange(completion: @escaping (S1CloudKitFetchResult) -> Void) {
        var previousChangeToken: CKServerChangeToken? = nil

        databaseConnection.read { (transaction) in
            previousChangeToken = transaction.object(forKey: Key_serverChangeToken, inCollection: Collection_cloudKit) as? CKServerChangeToken
        }

        fetchRecordChange(with: previousChangeToken, completion: completion)
    }

    private func fetchRecordChange(with previousServerChangeToken: CKServerChangeToken?, completion: @escaping (S1CloudKitFetchResult) -> Void) {
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
                    transaction.setObject(serverChangeToken, forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
                })
            } else {
                strongSelf.databaseConnection.readWrite({ (transaction) in
                    transaction.deleteKeysAssociatedWithRecordIDs(deletedRecordIDs)
                    transaction.updateDatabaseWithRecords(changedRecords)
                    transaction.setObject(serverChangeToken, forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
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
                completion(.failed(recordZoneError))
                return
            }

            let hasChange = deletedRecordIDs.count > 0 || changedRecords.count > 0

            if !hasChange {
                // We do not have any change in cloud. Just save the new server change token
                strongSelf.databaseConnection.readWrite({ (transaction) in
                    transaction.setObject(serverChangeToken, forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
                })

                completion(.noData)
            } else {
                strongSelf.databaseConnection.readWrite({ (transaction) in
                    transaction.deleteKeysAssociatedWithRecordIDs(deletedRecordIDs)
                    transaction.updateDatabaseWithRecords(changedRecords)
                    transaction.setObject(serverChangeToken, forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
                })

                completion(.newData)
            }
        }

        cloudKitContainer.privateCloudDatabase.add(fetchOperation)
    }
}

// MARK: Error Handling

extension CloudKitManager1 {
    func handleCreateZoneError(_ error: Error) {
        S1LogWarn("Error creating zone: \(error)")

        errors.append(.createZoneError(error))

        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                alertAccountAuthIssue()
            case .quotaExceeded:
                alertQuotaExceedIssue()
            case .internalError:
                // Halt silently
                break
            case .partialFailure:
                #if DEBUG
                alertAssertFailure()
                #else
                #endif
            default:
                S1LogWarn("Other error case.")
            }
        } else {
            S1LogWarn("Other error domain.")
        }
    }

    func handleCreateZoneSubscriptionError(_ error: Error) {
        S1LogWarn("Error creating zone subscription: \(error)")

        errors.append(.createZoneSubscriptionError(error))

        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                alertAccountAuthIssue()
            case .quotaExceeded:
                alertQuotaExceedIssue()
            case .internalError:
                // Halt silently
                break
            default:
                S1LogWarn("Other error case.")
            }
        } else {
            S1LogWarn("Other error domain.")
        }
    }

    func handleFetchRecordChangesError(_ error: Error) {
        S1LogWarn("Fetch Record Changes Error: \(error)")

        errors.append(.fetchChangesError(error))

        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                alertAccountAuthIssue()
            case .quotaExceeded:
                #if DEBUG
                alertAssertFailure()
                #else
                alertQuotaExceedIssue()
                #endif

            case .internalError:
                // Halt silently
                break
            case .networkUnavailable, .networkFailure:
                let delay = ckError.retryAfterSeconds ?? 30.0
                queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.state.value = .fetchRecordChanges
                }
            case .requestRateLimited, .serviceUnavailable:
                let delay = ckError.retryAfterSeconds ?? 60.0
                queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.state.value = .fetchRecordChanges
                }
            case .partialFailure:
                #if DEBUG
                alertAssertFailure()
                #else
                break
                #endif

            case .userDeletedZone:
                break
            case .changeTokenExpired:
                databaseConnection.readWrite { (transaction) in
                    transaction.removeObject(forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
                }

                state.value = .fetchRecordChanges
            default:
                break
            }
        }
    }

    @objc func handleUploadError(_ error: Error) {
        // When the YapDatabaseCloudKitOperationErrorBlock is invoked,
        // the extension has already automatically suspended itself.
        // It is our job to properly handle the error, and resume the extension when ready.

        S1LogWarn("Upload Error: \(error)")

        errors.append(.uploadError(error))

        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                alertAccountAuthIssue()
            case .quotaExceeded:
                alertQuotaExceedIssue()
            case .internalError:
                // Halt silently
                break
            case .networkUnavailable, .networkFailure:
                let delay = ckError.retryAfterSeconds ?? 30.0
                queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.cloudKitExtension.resume()
                    strongSelf.state.value = .readyForUpload
                }
            case .requestRateLimited, .serviceUnavailable:
                let delay = ckError.retryAfterSeconds ?? 60.0
                queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.cloudKitExtension.resume()
                    strongSelf.state.value = .readyForUpload
                }
            case .partialFailure:
                handlePartialFailure(ckError: ckError)
            case .userDeletedZone:
                break
            case .changeTokenExpired:
                #if DEBUG
                alertAssertFailure()
                #else
                #endif
            default:
                break
            }
        }

//        if ([operationError.domain isEqualToString:CKErrorDomain]) {
//            NSInteger ckErrorCode = operationError.code;
//            [MyCloudKitManager reportError:operationError];
//
//            if (ckErrorCode == CKErrorNetworkUnavailable ||
//                ckErrorCode == CKErrorNetworkFailure      ) {
//                [MyCloudKitManager handleNetworkError];
//            }
//            else if (ckErrorCode == CKErrorPartialFailure) {
//                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                    [MyCloudKitManager handlePartialFailure];
//                    });
//            }
//            else if (ckErrorCode == CKErrorNotAuthenticated) {
//                [MyCloudKitManager handleNotAuthenticated];
//            }
//            else if (ckErrorCode == CKErrorRequestRateLimited ||
//                ckErrorCode == CKErrorServiceUnavailable  ) {
//                [MyCloudKitManager handleRequestRateLimitedAndServiceUnavailableWithError:operationError];
//            }
//            else if (ckErrorCode == CKErrorUserDeletedZone) {
//                [MyCloudKitManager handleUserDeletedZone];
//            }
//            else if (ckErrorCode == CKErrorChangeTokenExpired) {
//                [MyCloudKitManager handleChangeTokenExpired];
//            }
//            else {
//                [MyCloudKitManager handleOtherErrors];
//            }
//        }
    }

    func handlePartialFailure(ckError: CKError) {
        guard let errors = ckError.partialErrorsByItemID else {
            return
        }

        var shouldResume: Bool = false
        var shouldRefetchRecords: Bool = false

        EnumerateErrors: for (_, value) in errors {
            guard let error = value as? CKError else {
                continue EnumerateErrors
            }

            switch error.code {
            case .serverRecordChanged:
                S1LogWarn("""
                    Upload Partial Failure: \(error)
                    ServerRecord: \(String(describing: error.serverRecord))
                    ClientRecord: \(String(describing: error.clientRecord))
                    """)

                guard let serverRecord = error.serverRecord else {
                    continue EnumerateErrors
                }

                databaseConnection.readWrite { (transaction) in
                    transaction.updateDatabaseWithRecords([serverRecord])
                }

                shouldResume = true
            case .quotaExceeded:
                alertQuotaExceedIssue()
                break EnumerateErrors
            case .unknownItem: // recordChangeTag specified, but record not found
                // Record may be deleted by other device and the deletion synced to server and we are not getting it yet.
                shouldRefetchRecords = true
            default:
                break
            }
        }

        if shouldRefetchRecords {
            state.value = .fetchRecordChanges
        } else if shouldResume {
            cloudKitExtension.resume()
        }
    }

    func alertAccountAuthIssue() {
        DispatchQueue.main.async {
            MessageHUD.shared.post(
                message: "请在 iOS 系统设置中登录 iCloud 或启用应用 iCloud 功能以使用同步功能。",
                duration: 1.0,
                animated: true
            )
        }
    }

    func alertQuotaExceedIssue() {
        DispatchQueue.main.async {
            MessageHUD.shared.post(
                message: "iCloud 空间不足，请确保足够空间以使用同步功能。您可以到 iOS 系统设置中清理",
                duration: 1.0,
                animated: true
            )
        }
    }

    func alertAssertFailure() {
        DispatchQueue.main.async {
            MessageHUD.shared.post(
                message: "Assert Failure",
                duration: .forever,
                animated: true
            )
        }
    }
}

extension CloudKitManager1 {
    @objc func setStateToUploadError(_ error: Error) {
        state.value = .uploadError(error)
    }
}

// MARK: -

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

        self.getRecordChangeTag(
            &recordChangeTag,
            hasPendingModifications: &hasPendingModifications,
            hasPendingDelete: &hasPendingDelete,
            for: recordID,
            databaseIdentifier: databaseIdentifier
        )

        return (
            recordChangeTag.map { $0 as String },
            hasPendingModifications.boolValue,
            hasPendingDelete.boolValue
        )
    }
}

enum S1CloudKitFetchResult: CustomDebugStringConvertible {
    case failed(Error)
    case noData
    case newData

    public var debugDescription: String {
        switch self {
        case let .failed(error):
            return "failed with error: \(error)"
        case .noData:
            return "noData"
        case .newData:
            return "newData"
        }
    }

    func toUIBackgroundFetchResult() -> UIBackgroundFetchResult {
        switch self {
        case .failed:
            return .failed
        case .noData:
            return .noData
        case .newData:
            return .newData

        }
    }
}

extension CKAccountStatus: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .available:
            return "available"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        }
    }
}

extension CloudKitManager1.State: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .waitingSetupTriggered:
            return "waitingSetupTriggered"
        case .migrating:
            return "migrating"
        case .createZone:
            return "createZone"
        case .createZoneError:
            return "createZoneError"
        case .createZoneSubscription:
            return "createZoneSubscription"
        case .createZoneSubscriptionError:
            return "createZoneSubscriptionError"
        case .fetchRecordChanges:
            return "fetchRecordChanges"
        case .fetchRecordChangesError:
            return "fetchRecordChangesError"
        case .readyForUpload:
            return "readyForUpload"
        case .uploadError:
            return "uploadError"
        case .halt:
            return "halt"
        }
    }
}

enum S1CloudKitError: Error {
    case createZoneError(Error)
    case createZoneSubscriptionError(Error)
    case fetchChangesError(Error)
    case uploadError(Error)
}
