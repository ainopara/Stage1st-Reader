//
//  CloudKitManager.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/4/16.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import CloudKit
import ReactiveSwift
import Combine
import YapDatabase
import CocoaLumberjack
import Reachability

private let cloudkitZoneName = "zone1"

private let Collection_cloudKit = "cloudKit"

private let Key_cloudKitManagerVersion = "CloudKitManagerVersion"
private let Key_userIdentity = "userIdentity"
private let Key_hasZone = "hasZone"
private let Key_hasZoneSubscription = "hasZoneSubscription"
private let Key_serverChangeToken = "serverChangeToken"

private let cloudKitManagerVersion = 1

class CloudKitManager: NSObject {
    let cloudKitContainer: CKContainer
    let databaseManager: DatabaseManager
    let databaseConnection: YapDatabaseConnection
    let cloudKitExtension: YapDatabaseCloudKit

    private(set) var state: CurrentValueSubject<State, Never> = CurrentValueSubject(.waitingSetupTriggered)
    private(set) var accountStatus: MutableProperty<CKAccountStatus> = MutableProperty(.couldNotDetermine)

    private var fetchCompletionHandlers: [(S1CloudKitFetchResult) -> Void] = []
    private var pendingFetchCompletionHandlers: [(S1CloudKitFetchResult) -> Void] = []

    let queue = DispatchQueue(label: "com.ainopara.stage1st.cloudkit")

    var errors: [S1CloudKitError] = []

    enum State {
        case waitingSetupTriggered
        case migrating
        case identifyUser
        case createZone
        case createZoneError(Error)
        case createZoneSubscription
        case createZoneSubscriptionError(Error)
        case fetchRecordChanges
        case fetchRecordChangesError(Error)
        case readyForUpload
        case uploadError(Error)
        case networkError(Error)
        case halt
    }

    private var bag = Set<AnyCancellable>()

    func updateAccountStatus() {
        cloudKitContainer.accountStatus { [weak self] (accountStatus, error) in
            guard let strongSelf = self else { return }
            strongSelf.accountStatus.value = accountStatus

            if let error = error {
                S1LogWarn("CloudKit Account Change Fetch Error: \(error)")
            }
        }
    }

    // swiftlint:disable cyclomatic_complexity
    init(
        cloudkitContainer: CKContainer,
        databaseManager: DatabaseManager
    ) {
        self.cloudKitContainer = cloudkitContainer
        self.databaseManager = databaseManager
        self.databaseConnection = databaseManager.bgDatabaseConnection
        self.cloudKitExtension = databaseManager.cloudKitExtension

        super.init()

        updateAccountStatus()

        NotificationCenter.default.reactive
            .notifications(forName: .CKAccountChanged)
            .signal.observeValues { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.updateAccountStatus()
        }

        NotificationCenter.default.reactive
            .notifications(forName: UIApplication.willEnterForegroundNotification)
            .signal.observeValues { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.setNeedsFetchChanges(completion: { (_) in
                    S1LogDebug("UIApplicationWillEnterForeground triggered fetch operation completed.")
                })
        }

        NotificationCenter.default.reactive
            .notifications(forName: .reachabilityChanged)
            .signal.observeValues { [weak self] (_) in
                if AppEnvironment.current.reachability.isReachable() {
                    guard let strongSelf = self else { return }
                    if case .networkError = strongSelf.state.value {
                        S1LogDebug("Trying to recover from network error (source: reachability)")
                        strongSelf.transitState(to: .identifyUser)
                    }
                }
        }

        state.sink { [weak self] (state) in
            guard let strongSelf = self else { return }

            switch state {
            case .waitingSetupTriggered:
                strongSelf.ensureSuspend()

            case .migrating:
                strongSelf.ensureSuspend()
                strongSelf.migrateIfNecessary()

            case .identifyUser:
                strongSelf.ensureSuspend()
                strongSelf.identifyUser()

            case .createZone:
                strongSelf.ensureSuspend()
                strongSelf.createZoneIfNecessary()

            case let .createZoneError(error):
                strongSelf.ensureSuspend()
                strongSelf.handleCreateZoneError(error)

            case .createZoneSubscription:
                strongSelf.ensureSuspend()
                strongSelf.createZoneSubscriptionIfNecessary()

            case let .createZoneSubscriptionError(error):
                strongSelf.ensureSuspend()
                strongSelf.handleCreateZoneSubscriptionError(error)

            case .fetchRecordChanges:
                strongSelf.ensureSuspend()
                strongSelf.fetchRecordChange { [weak self] (fetchResult) in
                    S1LogDebug("Fetch finished with result: \(fetchResult.debugDescription)")
                    guard let strongSelf = self else { return }

                    for completionHandler in strongSelf.fetchCompletionHandlers {
                        completionHandler(fetchResult)
                    }
                    strongSelf.fetchCompletionHandlers.removeAll()

                    switch fetchResult {
                    case .newData, .noData:
                        strongSelf.transitState(to: .readyForUpload)
                    case let .failed(error):
                        strongSelf.transitState(to: .fetchRecordChangesError(error))
                    }
                }

            case let .fetchRecordChangesError(error):
                strongSelf.ensureSuspend()
                strongSelf.handleFetchRecordChangesError(error)

            case .readyForUpload:
                if strongSelf.fetchCompletionHandlers.count + strongSelf.pendingFetchCompletionHandlers.count > 0 {
                    strongSelf.fetchCompletionHandlers.append(contentsOf: strongSelf.pendingFetchCompletionHandlers)
                    strongSelf.pendingFetchCompletionHandlers.removeAll()
                    strongSelf.transitState(to: .fetchRecordChanges)
                } else {
                    strongSelf.ensureResume()
                }
            case let .uploadError(error):
                strongSelf.handleUploadError(error)

            case let .networkError(error):
                S1LogDebug("Network error \(error).")

                strongSelf.queue.asyncAfter(deadline: .now() + 30.0, execute: { [weak self] in
                    guard let strongSelf = self else { return }
                    if case .networkError = strongSelf.state.value {
                        S1LogDebug("Trying to recover from network error (source: timer)")
                        strongSelf.transitState(to: .identifyUser)
                    } else {
                        S1LogInfo("Network Error recover timer fired but we are not in network error state.")
                    }
                })

            case .halt:
                strongSelf.ensureSuspend()
            }
        }.store(in: &bag)

        // Debug
//        state.combinePrevious().startWithValues { (previous, current) in
//            S1LogDebug("State: \(previous) -> \(current)")
//        }
        // TODO: Implement combinePrevious for Combine

        accountStatus.producer.combinePrevious().startWithValues { (previous, current) in
            S1LogDebug("AccountStatus: \(previous.debugDescription) -> \(current.debugDescription)")
        }
    }

    func setup() {
        queue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.transitState(to: .migrating)
        }
    }

    @objc func unregister(completion: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.transitState(to: .waitingSetupTriggered)

            strongSelf.databaseConnection.readWrite { (transaction) in
                transaction.removeObject(forKey: Key_userIdentity, inCollection: Collection_cloudKit)
                transaction.removeObject(forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
                transaction.removeObject(forKey: Key_hasZone, inCollection: Collection_cloudKit)
                transaction.removeObject(forKey: Key_hasZoneSubscription, inCollection: Collection_cloudKit)
            }

            strongSelf.databaseManager.database.unregisterExtension(withName: Ext_CloudKit)
            S1LogDebug("Exrension CloudKit unregistered.")
            completion()
        }
    }

    func setNeedsFetchChanges(completion: @escaping (S1CloudKitFetchResult) -> Void) {
        queue.async { [weak self] in
            guard let strongSelf = self else { return }
            switch strongSelf.state.value {
            case .readyForUpload:
                strongSelf.fetchCompletionHandlers.append(completion)
                strongSelf.transitState(to: .fetchRecordChanges)

            case .fetchRecordChanges:
                strongSelf.pendingFetchCompletionHandlers.append(completion)

            case .migrating, .identifyUser, .createZone, .createZoneSubscription:
                strongSelf.fetchCompletionHandlers.append(completion)

            case .networkError:
                strongSelf.fetchCompletionHandlers.append(completion)

            case let .createZoneError(error), let .createZoneSubscriptionError(error), let .fetchRecordChangesError(error), let .uploadError(error):
                completion(.failed(error))

            case .waitingSetupTriggered, .halt:
                completion(.noData)
            }
        }
    }

    private func ensureSuspend() {
        if !cloudKitExtension.isSuspended {
            cloudKitExtension.suspend()
        }
    }

    private func ensureResume() {
        while cloudKitExtension.isSuspended {
            cloudKitExtension.resume()
        }
    }
}

// MARK: Processes

private extension CloudKitManager {
    func migrateIfNecessary() {
        guard AppEnvironment.current.settings.enableCloudKitSync.value else {
            S1LogInfo("migrateIfNecessary cancelled.")
            return
        }

        defer { self.transitState(to: .identifyUser) }

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

    func identifyUser() {
        guard AppEnvironment.current.settings.enableCloudKitSync.value else {
            S1LogInfo("identifyUser cancelled.")
            return
        }

        cloudKitContainer.fetchUserRecordID { (userRecordID, error) in
            self.queue.async { [weak self] in
                if let userRecordID = userRecordID {
                    S1LogDebug("UserRecordID: \(userRecordID)")
                }

                if let error = error {
                    S1LogDebug("Error: \(error)")
                }

                guard let strongSelf = self else { return }

                guard AppEnvironment.current.settings.enableCloudKitSync.value else {
                    S1LogInfo("identifyUser callback cancelled.")
                    return
                }

                // Save userRecordID

                strongSelf.transitState(to: .createZone)
            }
        }
    }

    func createZoneIfNecessary() {
        guard AppEnvironment.current.settings.enableCloudKitSync.value else {
            S1LogInfo("createZoneIfNecessary cancelled.")
            return
        }

        var needsCreateZone = true
        databaseConnection.read { (transaction) in
            if transaction.hasObject(forKey: Key_hasZone, inCollection: Collection_cloudKit) {
                needsCreateZone = false
            }
        }

        guard needsCreateZone else {
            S1LogDebug("Skip creating zone.")
            self.transitState(to: .createZoneSubscription)
            return
        }

        /// Typically, default zones do not support any special capabilities. Custom zones in a private database normally support all options.
        /// We create a custom zone to get the capability of fetch record changes.
        let recordZone = CKRecordZone(zoneName: cloudkitZoneName)
        let modifyRecordZonesOperation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone], recordZoneIDsToDelete: nil)
        modifyRecordZonesOperation.modifyRecordZonesCompletionBlock = { (savedRecordZones, deletedRecordZoneIDs, operationError) in
            self.queue.async { [weak self] in
                guard let strongSelf = self else { return }
                guard AppEnvironment.current.settings.enableCloudKitSync.value else {
                    S1LogInfo("createZoneIfNecessary callback cancelled.")
                    return
                }

                if let operationError = operationError {
                    strongSelf.transitState(to: .createZoneError(operationError))
                    return
                }

                S1LogDebug("Successfully created zones: \(String(describing: savedRecordZones))")

                strongSelf.databaseConnection.readWrite({ (transaction) in
                    transaction.setObject(true, forKey: Key_hasZone, inCollection: Collection_cloudKit)
                })

                strongSelf.transitState(to: .createZoneSubscription)
            }
        }

        cloudKitContainer.privateCloudDatabase.add(modifyRecordZonesOperation)
    }

    func createZoneSubscriptionIfNecessary() {
        guard AppEnvironment.current.settings.enableCloudKitSync.value else {
            S1LogInfo("createZoneSubscriptionIfNecessary cancelled.")
            return
        }

        var needsCreateZoneSubscription: Bool = true
        databaseConnection.read { (transaction) in
            if transaction.hasObject(forKey: Key_hasZoneSubscription, inCollection: Collection_cloudKit) {
                needsCreateZoneSubscription = false
            }
        }

        guard needsCreateZoneSubscription else {
            S1LogDebug("Skip creating zone subscription.")
            self.transitState(to: .fetchRecordChanges)
            return
        }

        let recordZoneID = CKRecordZone.ID(zoneName: cloudkitZoneName, ownerName: CKCurrentUserDefaultName)
        let subscription = CKRecordZoneSubscription(zoneID: recordZoneID, subscriptionID: cloudkitZoneName)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let modifySubscriptionsOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        modifySubscriptionsOperation.modifySubscriptionsCompletionBlock = { (savedSubscriptions, deletedSubscriptionIDs, operationError) in
            self.queue.async { [weak self] in
                guard let strongSelf = self else { return }
                guard AppEnvironment.current.settings.enableCloudKitSync.value else {
                    S1LogInfo("createZoneSubscriptionIfNecessary callback cancelled.")
                    return
                }

                if let operationError = operationError {
                    strongSelf.transitState(to: .createZoneSubscriptionError(operationError))
                    return
                }

                S1LogDebug("Successfully created subscription: \(String(describing: savedSubscriptions))")

                strongSelf.databaseConnection.readWrite({ (transaction) in
                    transaction.setObject(true, forKey: Key_hasZoneSubscription, inCollection: Collection_cloudKit)
                })

                strongSelf.transitState(to: .fetchRecordChanges)
            }
        }

        cloudKitContainer.privateCloudDatabase.add(modifySubscriptionsOperation)
    }

    func fetchRecordChange(completion: @escaping (S1CloudKitFetchResult) -> Void) {
        guard AppEnvironment.current.settings.enableCloudKitSync.value else {
            S1LogInfo("fetchRecordChange cancelled.")
            return
        }

        var previousChangeToken: CKServerChangeToken?

        databaseConnection.read { (transaction) in
            previousChangeToken = transaction.object(forKey: Key_serverChangeToken, inCollection: Collection_cloudKit) as? CKServerChangeToken
        }

        fetchRecordChange(with: previousChangeToken, completion: completion)
    }

    private func fetchRecordChange(with previousServerChangeToken: CKServerChangeToken?, completion: @escaping (S1CloudKitFetchResult) -> Void) {
        let recordZoneID = CKRecordZone.ID(zoneName: cloudkitZoneName, ownerName: CKCurrentUserDefaultName)
        let fetchConfiguration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        fetchConfiguration.previousServerChangeToken = previousServerChangeToken

        let fetchOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [recordZoneID], configurationsByRecordZoneID: [recordZoneID: fetchConfiguration])
        var deletedRecordIDs = [CKRecord.ID]()
        var changedRecords = [CKRecord]()

        fetchOperation.recordWithIDWasDeletedBlock = { (recordID, recordType) in
            self.queue.async {
                deletedRecordIDs.append(recordID)
            }
        }

        fetchOperation.recordChangedBlock = { record in
            self.queue.async {
                changedRecords.append(record)
            }
        }

        fetchOperation.recordZoneChangeTokensUpdatedBlock = { (recordZoneID, serverChangeToken, clientChangeTokenData) in
            self.queue.async { [weak self] in
                guard AppEnvironment.current.settings.enableCloudKitSync.value else {
                    S1LogInfo("fetchRecordChange recordZoneChangeTokensUpdatedBlock skipped.")
                    if !fetchOperation.isCancelled { fetchOperation.cancel() }
                    return
                }

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
        }

        var completionHandlerAlreadyCalled = false

        /// We are assuming if this block get called with a nonnull error, then `recordZoneFetchCompletionBlock` will not get called.
        fetchOperation.fetchRecordZoneChangesCompletionBlock = { (error) in
            self.queue.async {
                S1LogDebug("fetchRecordZoneChangesCompletionBlock called with error: \(String(describing: error))")
                if let error = error {
                    guard !completionHandlerAlreadyCalled else {
                        S1LogError("We're assuming completion handler only called once!")
                        return
                    }
                    completion(.failed(error))
                    completionHandlerAlreadyCalled = true
                } else {
                    /// If error == nil, then `recordZoneFetchCompletionBlock` will be called so we do not call completionHandler here.
                }
            }
        }

        fetchOperation.recordZoneFetchCompletionBlock = { (recordZoneID, serverChangeToken, clientChangeTokenData, moreComing, recordZoneError) in
            self.queue.async { [weak self] in
                guard AppEnvironment.current.settings.enableCloudKitSync.value else {
                    S1LogInfo("fetchRecordChange recordZoneFetchCompletionBlock skipped.")
                    if !fetchOperation.isCancelled { fetchOperation.cancel() }
                    return
                }

                S1LogDebug("CKFetchRecordChangesOperation: serverChangeToken final: \(String(describing: serverChangeToken))")
                S1LogDebug("deleted: \(deletedRecordIDs.count) changed: \(changedRecords.count)")

                guard let strongSelf = self else { return }

                if let recordZoneError = recordZoneError {
                    S1LogError("recordZoneError: \(recordZoneError)")
                    guard !completionHandlerAlreadyCalled else {
                        S1LogError("We're assuming completion handler only called once!")
                        return
                    }
                    completion(.failed(recordZoneError))
                    completionHandlerAlreadyCalled = true
                    return
                }

                let hasChange = deletedRecordIDs.count > 0 || changedRecords.count > 0

                if !hasChange {
                    // We do not have any change in cloud. Just save the new server change token
                    strongSelf.databaseConnection.readWrite({ (transaction) in
                        transaction.setObject(serverChangeToken, forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
                    })

                    guard !completionHandlerAlreadyCalled else {
                        S1LogError("We're assuming completion handler only called once!")
                        return
                    }
                    completion(.noData)
                    completionHandlerAlreadyCalled = true
                } else {
                    strongSelf.databaseConnection.readWrite({ (transaction) in
                        transaction.deleteKeysAssociatedWithRecordIDs(deletedRecordIDs)
                        transaction.updateDatabaseWithRecords(changedRecords)
                        transaction.setObject(serverChangeToken, forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
                    })

                    guard !completionHandlerAlreadyCalled else {
                        S1LogError("We're assuming completion handler only called once!")
                        return
                    }
                    completion(.newData)
                    completionHandlerAlreadyCalled = true
                }
            }
        }

        cloudKitContainer.privateCloudDatabase.add(fetchOperation)
    }
}

// MARK: Error Handling

extension CloudKitManager {
    func handleCreateZoneError(_ error: Error) {
        guard AppEnvironment.current.settings.enableCloudKitSync.value else {
            S1LogInfo("handleCreateZoneError cancelled.")
            return
        }

        S1LogWarn("Error creating zone: \(error)")

        errors.append(.createZoneError(error))
        if let reportableError = S1CloudKitError.createZoneError(error).reportableError() {
            AppEnvironment.current.eventTracker.recordError(reportableError)
        }

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
                alertAssertFailure(message: "partialFailure in createZoneError.")
                #else
                break
                #endif

            default:
                S1LogWarn("Other error case.")
            }
        } else {
            transitState(to: .networkError(error))
        }
    }

    func handleCreateZoneSubscriptionError(_ error: Error) {
        guard AppEnvironment.current.settings.enableCloudKitSync.value else {
            S1LogInfo("handleCreateZoneSubscriptionError cancelled.")
            return
        }

        S1LogWarn("Error creating zone subscription: \(error)")

        errors.append(.createZoneSubscriptionError(error))

        if let reportableError = S1CloudKitError.createZoneSubscriptionError(error).reportableError() {
            AppEnvironment.current.eventTracker.recordError(reportableError)
        }

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
            transitState(to: .networkError(error))
        }
    }

    func handleFetchRecordChangesError(_ error: Error) {
        guard AppEnvironment.current.settings.enableCloudKitSync.value else {
            S1LogInfo("handleFetchRecordChangesError cancelled.")
            return
        }

        S1LogWarn("Fetch Record Changes Error: \(error)")

        errors.append(.fetchChangesError(error))

        if let reportableError = S1CloudKitError.fetchChangesError(error).reportableError() {
            AppEnvironment.current.eventTracker.recordError(reportableError)
        }

        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                alertAccountAuthIssue()

            case .quotaExceeded:
                #if DEBUG
                alertAssertFailure(message: "quotaExceeded in fetchRecordChangesError.")
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
                    strongSelf.transitState(to: .fetchRecordChanges)
                }

            case .requestRateLimited, .serviceUnavailable:
                let delay = ckError.retryAfterSeconds ?? 60.0
                queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.transitState(to: .fetchRecordChanges)
                }

            case .partialFailure:
                #if DEBUG
                alertAssertFailure(message: "partialFailure in fetchRecordChangesError.")
                #else
                break
                #endif

            case .userDeletedZone:
                alertUserDeleteZoneIssue()

            case .zoneNotFound:
                alertZoneNotFoundIssue()

            case .changeTokenExpired:
                databaseConnection.readWrite { (transaction) in
                    transaction.removeObject(forKey: Key_serverChangeToken, inCollection: Collection_cloudKit)
                }

                self.transitState(to: .fetchRecordChanges)
            default:
                break
            }
        } else {
            transitState(to: .networkError(error))
        }
    }

    @objc func handleUploadError(_ error: Error) {
        // When the YapDatabaseCloudKitOperationErrorBlock is invoked,
        // the extension has already automatically suspended itself.
        // It is our job to properly handle the error, and resume the extension when ready.

        S1LogWarn("Upload Error: \(error)")

        errors.append(.uploadError(error))

        if let reportableError = S1CloudKitError.uploadError(error).reportableError() {
            AppEnvironment.current.eventTracker.recordError(reportableError)
        }

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
                    strongSelf.transitState(to: .readyForUpload)
                }

            case .requestRateLimited, .serviceUnavailable, .zoneBusy:
                let delay = ckError.retryAfterSeconds ?? 60.0
                queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.transitState(to: .readyForUpload)
                }

            case .partialFailure:
                handlePartialFailure(ckError: ckError)

            case .userDeletedZone:
                alertUserDeleteZoneIssue()

            case .zoneNotFound:
                alertZoneNotFoundIssue()

            case .changeTokenExpired:
                #if DEBUG
                alertAssertFailure(message: "changeTokenExpired in uploadError.")
                #else
                break
                #endif

            default:
                break
            }
        } else {
            transitState(to: .networkError(error))
        }
    }

    func handlePartialFailure(ckError: CKError) {
        guard let errors = ckError.partialErrorsByItemID else {
            return
        }

        var shouldResume: Bool = false
        var shouldRefetchRecords: Bool = false
        var recordsToUpdate = [CKRecord]()

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

                recordsToUpdate.append(serverRecord)
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

        databaseConnection.readWrite { (transaction) in
            transaction.updateDatabaseWithRecords(recordsToUpdate)
        }

        if shouldRefetchRecords {
            fetchRecordChange { [weak self] (fetchResult) in
                S1LogDebug("Fetch finished with result: \(fetchResult.debugDescription)")
                guard let strongSelf = self else { return }
                switch fetchResult {
                case .newData:
                    // We got new data during this fetch, hope this will fix the unknownItem issue.
                    strongSelf.transitState(to: .readyForUpload)
                case .noData:
                    // We got no data during this fetch, that means unknownItem issue will not get fixed.
                    // We should either
                    // 1. remove local data
                    // or 2. upload our CKRecord with tag changed to nil
                    // Which one to choose should be depended on when the data get removed.
                    // Currently we just stop here to avoid infinity loop.
                    break
                case let .failed(error):
                    // We failed this fetch request, go to standard error handling route to recover and drop current state.
                    strongSelf.transitState(to: .fetchRecordChangesError(error))
                }
            }
        } else if shouldResume {
            transitState(to: .readyForUpload)
        }
    }

    func alertAccountAuthIssue() {
        DispatchQueue.main.async {
            Toast.shared.post(
                message: "请在 iOS 系统设置中登录 iCloud 或启用应用 iCloud 功能以使用同步功能。",
                duration: 1.0,
                animated: true
            )
        }
    }

    func alertQuotaExceedIssue() {
        DispatchQueue.main.async {
            Toast.shared.post(
                message: "iCloud 空间不足，请确保足够空间以使用同步功能。您可以到 iOS 系统设置中清理 iCloud 空间。",
                duration: 1.0,
                animated: true
            )
        }
    }

    func alertUserDeleteZoneIssue() {
        DispatchQueue.main.async {
            Toast.shared.post(
                message: "检测到云端数据已删除。同步暂停，若要与当前 iCloud 帐号同步，请在应用设置中关闭再重新开启 iCloud 同步开关。",
                duration: 1.0,
                animated: true
            )
        }
    }

    func alertZoneNotFoundIssue() {
        DispatchQueue.main.async {
            Toast.shared.post(
                message: "云端数据未初始化。同步暂停，若要与当前 iCloud 帐号同步，请在应用设置中关闭再重新开启 iCloud 同步开关。",
                duration: 1.0,
                animated: true
            )
        }
    }

    func alertAssertFailure(message: String) {
        DispatchQueue.main.async {
            Toast.shared.post(
                message: "Assert Failure: \(message)",
                duration: .forever,
                animated: true
            )
        }
    }
}

extension CloudKitManager {
    @objc func setStateToUploadError(_ error: Error) {
        self.transitState(to: .uploadError(error))
    }
}

// MARK: -

private extension YapDatabaseReadWriteTransaction {
    func deleteKeysAssociatedWithRecordIDs(_ recordIDs: [CKRecord.ID]) {
        guard let cloudkitTransaction = self.ext(Ext_CloudKit) as? YapDatabaseCloudKitTransaction else {
            // CloudKit Extension is unregistered.
            return
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
            // CloudKit Extension is unregistered.
            return
        }

        // Ignore unknown record types.
        // These are probably from a future version that this version doesn't support.
        for record in records where record.recordType == "topic" {
            let (recordChangeTag, hasPendingModifications, hasPendingDelete) = cloudkitTransaction.getRecordChangeTag(for: record.recordID, databaseIdentifier: nil)
            let containsRecord = cloudkitTransaction.contains(record.recordID, databaseIdentifier: nil)

            enum RecordStatus {
                case noRecord
                case newRecord
                case managed(tag: String)
            }

            func isManaged(containsRecord: Bool, changeTag: String?) -> RecordStatus {
                switch (containsRecord, recordChangeTag) {
                case (true, .none):
                    return .newRecord
                case (true, .some(let tag)):
                    return .managed(tag: tag)
                case (false, _):
                    return .noRecord
                }
            }

            switch (isManaged(containsRecord: containsRecord, changeTag: recordChangeTag), hasPendingModifications, hasPendingDelete) {
            case (.managed(let recordChangeTag), _, _):
                // We have a record change tag in database
                // So the record is currently managed by database
                if recordChangeTag == record.recordChangeTag {
                    // We're the one who changed this record.
                    // So we can quietly ignore it.
                } else {
                    // Other device changed this record, or the record is changed by this device but not the latest change.
                    cloudkitTransaction.merge(record, databaseIdentifier: nil)
                }
            case (.newRecord, _, _):
                // We have managed record in database,
                // but it is generated by extension registaration (i.e. `populated from database object`) and do not have a change tag.

                cloudkitTransaction.merge(record, databaseIdentifier: nil)
            case (.noRecord, true, _):
                // We're not actively managing this record anymore (we deleted/detached it).
                // But there are still previous modifications that are pending upload to server.
                // So this merge is required in order to keep everything running properly (no infinite loops).

                cloudkitTransaction.merge(record, databaseIdentifier: nil)
            case (.noRecord, false, false):
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
            case (.noRecord, false, true):
                // We're going to delete this record, so do not add it.
                // Nothing to do.
                break
            }
        }
    }
}

private extension YapDatabaseCloudKitTransaction {
    func getRecordChangeTag(for recordID: CKRecord.ID, databaseIdentifier: String?) -> (String?, Bool, Bool) {
        var recordChangeTag: NSString?
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
        @unknown default:
            return "unknown(\(self.rawValue))"
        }
    }
}

extension CloudKitManager.State: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .waitingSetupTriggered:
            return "waitingSetupTriggered"
        case .migrating:
            return "migrating"
        case .identifyUser:
            return "identifyUser"
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
        case .networkError:
            return "networkError"
        case .halt:
            return "halt"
        }
    }
}

extension CloudKitManager {
    func transitState(to newState: CloudKitManager.State) {
        self.queue.async {
            switch (self.state.value, newState) {
            // Normal Routine
            case (.waitingSetupTriggered, .migrating),
                 (.migrating, .identifyUser),
                 (.identifyUser, .createZone),
                 (.createZone, .createZoneSubscription),
                 (.createZoneSubscription, .fetchRecordChanges),
                 (.fetchRecordChanges, .readyForUpload):
                self.state.value = newState
            // Exceptions
            case (.createZone, .createZoneError),
                 (.createZoneSubscription, .createZoneSubscriptionError),
                 (.fetchRecordChanges, .fetchRecordChangesError),
                 (.readyForUpload, .uploadError):
                self.state.value = newState
            // Recover
            case (.createZoneError, .createZone),
                 (.createZoneSubscriptionError, .createZoneSubscription),
                 (.fetchRecordChangesError, .fetchRecordChanges),
                 (.uploadError, .readyForUpload):
                self.state.value = newState
            // Unregister
            case (_, .waitingSetupTriggered):
                self.state.value = newState
            // Respond to Record Change Notification
            case (.readyForUpload, .fetchRecordChanges):
                self.state.value = newState
            // Recognized error as network error which can be recoved by reachability change.
            case (.createZoneError, .networkError),
                 (.createZoneSubscriptionError, .networkError),
                 (.fetchRecordChangesError, .networkError),
                 (.uploadError, .networkError):
                self.state.value = newState
            // Network Error will be recover to initial state to cover all error cases.
            case (.networkError, .identifyUser):
                self.state.value = newState
            default:
                S1LogError("Transition `\(self.state.value.debugDescription) -> \(newState.debugDescription)` will be ignored.")
            }
        }
    }
}

enum S1CloudKitError: Error {
    case createZoneError(Error)
    case createZoneSubscriptionError(Error)
    case fetchChangesError(Error)
    case uploadError(Error)

    func reportableError() -> NSError? {
        switch self {
        case let .createZoneError(error):
            if let ckError = error as? CKError {
                return NSError(
                    domain: "S1CloudKitCreateZoneError",
                    code: ckError.errorCode,
                    userInfo: ckError.userInfo
                )
            } else {
                let nsError = error as NSError
                guard !(nsError.domain == "kCFErrorDomainCFNetwork" && nsError.code == 310) else{
                    return nil
                }
                return NSError(
                    domain: "S1CloudKitCreateZoneError" + "-" + nsError.domain,
                    code: nsError.code,
                    userInfo: nsError.userInfo
                )
            }
        case let .createZoneSubscriptionError(error):
            if let ckError = error as? CKError {
                return NSError(
                    domain: "S1CloudKitCreateZoneSubscriptionError",
                    code: ckError.errorCode,
                    userInfo: ckError.userInfo
                )
            } else {
                let nsError = error as NSError
                guard !(nsError.domain == "kCFErrorDomainCFNetwork" && nsError.code == 310) else{
                    return nil
                }
                return NSError(
                    domain: "S1CloudKitCreateZoneSubscriptionError" + "-" + nsError.domain,
                    code: nsError.code,
                    userInfo: nsError.userInfo
                )
            }
        case let .fetchChangesError(error):
            if let ckError = error as? CKError {
                return NSError(
                    domain: "S1CloudKitFetchChangesError",
                    code: ckError.errorCode,
                    userInfo: ckError.userInfo
                )
            } else {
                let nsError = error as NSError
                guard !(nsError.domain == "kCFErrorDomainCFNetwork" && nsError.code == 310) else{
                    return nil
                }
                return NSError(
                    domain: "S1CloudKitFetchChangesError" + "-" + nsError.domain,
                    code: nsError.code,
                    userInfo: nsError.userInfo
                )
            }
        case let .uploadError(error):
            if let ckError = error as? CKError {
                if
                    ckError.code == .partialFailure,
                    let underlyingErrors = ckError.partialErrorsByItemID?.values.compactMap({ $0 as? CKError }),
                    let selectedError = underlyingErrors.filter({ $0.code != .batchRequestFailed }).first
                {
                    return NSError(
                        domain: "S1CloudKitUploadPartialFailureError",
                        code: selectedError.errorCode,
                        userInfo: selectedError.userInfo
                    )
                } else {
                    return NSError(
                        domain: "S1CloudKitUploadError",
                        code: ckError.errorCode,
                        userInfo: ckError.userInfo
                    )
                }
            } else {
                let nsError = error as NSError
                guard !(nsError.domain == "kCFErrorDomainCFNetwork" && nsError.code == 310) else{
                    return nil
                }
                return NSError(
                    domain: "S1CloudKitUploadError" + "-" + nsError.domain,
                    code: nsError.code,
                    userInfo: nsError.userInfo
                )
            }
        }
    }
}
