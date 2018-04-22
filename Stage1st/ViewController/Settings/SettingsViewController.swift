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
        return ColorManager.shared.isDarkTheme() ? .lightContent : .default
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
            UserDefaults.standard.set(Date(), forKey: Constants.defaults.previousWebKitCacheCleaningDateKey)
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
        Signal.combineLatest(
            NotificationCenter.default.reactive.notifications(forName: Notification.Name.YapDatabaseCloudKitSuspendCountChanged),
            NotificationCenter.default.reactive.notifications(forName: Notification.Name.YapDatabaseCloudKitInFlightChangeSetChanged),
            AppEnvironment.current.cloudkitManager.state.signal
        ).observeValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.updateCloudKitStatus()
        }

    }

    @objc func updateCloudKitStatus() {
        if AppEnvironment.current.settings.enableCloudKitSync.value {
            switch AppEnvironment.current.cloudkitManager.state.value {
            case .waitingSetupTriggered:
                iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Init", comment: "Init")
            case .migrating, .createZone, .createZoneSubscription:
                iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Setup", comment: "Setup")
            case .fetchRecordChanges:
                iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Fetch", comment: "Fetch")
            case .readyForUpload:
                let suspendCount = AppEnvironment.current.databaseManager.cloudKitExtension.suspendCount
                let inFlightCount = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfInFlightChangeSets
                let queuedCount = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfQueuedChangeSets
                if suspendCount == 0 && inFlightCount == 0 && queuedCount == 0 {
                    iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Ready", comment: "Ready")
                } else {
                    iCloudSyncCell.detailTextLabel?.text =
                        NSLocalizedString("SettingsViewController.CloudKit.Status.Fetch", comment: "Fetch") + "(\(inFlightCount) - \(queuedCount))"
                }

            case .createZoneError, .createZoneSubscriptionError, .fetchRecordChangesError, .uploadError:
                let suspendCount = AppEnvironment.current.databaseManager.cloudKitExtension.suspendCount
                iCloudSyncCell.detailTextLabel?.text =
                    NSLocalizedString("SettingsViewController.CloudKit.Status.Recover", comment: "Recover") + "(\(suspendCount))"
            case .halt:
                iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Halt", comment: "Halt")
            }
        } else {
            iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Off", comment: "Off")
        }
    }
}
