//
//  SettingsViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//
import UIKit
import AcknowList
import WebKit
import CocoaLumberjack
import CrashlyticsLogger
import ReactiveSwift
import ReactiveCocoa
import Files

extension SettingsViewController {
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
    }
}

extension SettingsViewController {
    @objc func applicationVersion() -> String {
        guard
            let shortVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString"),
            let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
        else {
            return "?"
        }
        return "\(shortVersionString) (\(versionString))"
    }
}

extension SettingsViewController {

    @objc func pushLogViewer() {
        let logViewController = InMemoryLogViewController()
        navigationController?.pushViewController(logViewController, animated: true)
    }

    @objc func acknowledgementListViewController() -> AcknowListViewController {
        let acknowledgmentPlistFilePath = Bundle.main.path(forResource: "Pods-Stage1st-acknowledgements", ofType: "plist")
        return AcknowListViewController(acknowledgementsPlistPath: acknowledgmentPlistFilePath)
    }

    @objc func clearWebKitCache() {
        let websiteDataTypes = Set([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])

        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: Date.distantPast) {
            S1LogInfo("WebKit disk cache cleaned.")
            AppEnvironment.current.settings.previousWebKitCacheCleaningDate.value = Date()
        }
    }

    @objc func totalCacheSize() -> UInt {
        var totalCacheSize = UInt(URLCache.shared.currentDiskUsage)
        if let libraryFolder = FileSystem().libraryFolder,
           let webKitCacheFolder = try? libraryFolder.subfolder(named: "Caches").subfolder(named: "WebKit") {
            for file in webKitCacheFolder.makeFileSequence(recursive: true, includeHidden: false) {
                S1LogVerbose("\(file.name)")
                if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let fileSize = fileAttributes[FileAttributeKey.size] as? UInt64 {
                    totalCacheSize += UInt(fileSize)
                }
            }
        }
        return totalCacheSize
    }

    @objc func setupObservation() {
        NotificationCenter.default.reactive
            .notifications(forName: .YapDatabaseCloudKitSuspendCountChanged)
            .signal.observeValues { [weak self] (_) in
                self?.updateCloudKitStatus(
                    state: AppEnvironment.current.cloudkitManager.state.value,
                    enableSync: AppEnvironment.current.settings.enableCloudKitSync.value
                )
            }

        NotificationCenter.default.reactive
            .notifications(forName: .YapDatabaseCloudKitInFlightChangeSetChanged)
            .signal.observeValues { [weak self] (_) in
                self?.updateCloudKitStatus(
                    state: AppEnvironment.current.cloudkitManager.state.value,
                    enableSync: AppEnvironment.current.settings.enableCloudKitSync.value
                )
            }

        MutableProperty.combineLatest(
            AppEnvironment.current.cloudkitManager.state,
            AppEnvironment.current.settings.enableCloudKitSync
        )
            .producer
            .startWithValues { [weak self] (args) in
                let (state, enableSync) = args
                self?.updateCloudKitStatus(state: state, enableSync: enableSync)
            }
    }

    @objc func setupInitialValue() {
        let settings = AppEnvironment.current.settings
        self.displayImageSwitch.isOn = settings.displayImage.value
        self.forcePortraitSwitch.isOn = settings.forcePortraitForPhone.value
        self.removeTailsSwitch.isOn = settings.removeTails.value
        self.precacheSwitch.isOn = settings.precacheNextPage.value
        self.nightModeSwitch.isOn = settings.nightMode.value
    }

    func updateCloudKitStatus(state: CloudKitManager.State, enableSync: Bool) {
        S1LogDebug("Observed CloudKit manager state changed.")
        DispatchQueue.main.async {
            guard enableSync else {
                self.iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Off", comment: "Off")
                return
            }

            switch state {
            case .waitingSetupTriggered:
                self.iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Off", comment: "Off")
//                self.iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Init", comment: "Init")
            case .migrating, .identifyUser, .createZone, .createZoneSubscription:
                self.iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Setup", comment: "Setup")
            case .fetchRecordChanges:
                self.iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Fetch", comment: "Fetch")
            case .readyForUpload:
                let suspendCount = AppEnvironment.current.databaseManager.cloudKitExtension.suspendCount
                let inFlightCount = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfInFlightChangeSets
                let queuedCount = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfQueuedChangeSets
                if suspendCount == 0 && inFlightCount == 0 && queuedCount == 0 {
                    self.iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Ready", comment: "Ready")
                } else {
                    self.iCloudSyncCell.detailTextLabel?.text =
                        NSLocalizedString("SettingsViewController.CloudKit.Status.Upload", comment: "Upload") + "(\(inFlightCount) - \(queuedCount))"
                }

            case .createZoneError, .createZoneSubscriptionError, .fetchRecordChangesError, .uploadError, .networkError:
                let suspendCount = AppEnvironment.current.databaseManager.cloudKitExtension.suspendCount
                self.iCloudSyncCell.detailTextLabel?.text =
                    NSLocalizedString("SettingsViewController.CloudKit.Status.Recover", comment: "Recover") + "(\(suspendCount))"
            case .halt:
                self.iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Halt", comment: "Halt")
            }
        }
    }
}
