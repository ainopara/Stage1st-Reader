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
import Ainoaibo
import ReactiveSwift
import ReactiveCocoa
import Combine
import Files
import Crashlytics
import SafariServices

final class SettingsViewController: UITableViewController {

    @IBOutlet weak var usernameDetailLabel: UILabel!
    @IBOutlet weak var fontSizeDetailLabel: UILabel!

    @IBOutlet weak var displayImageSwitch: UISwitch!
    @IBOutlet weak var keepHistoryDetailLabel: UILabel!
    @IBOutlet weak var removeTailsSwitch: UISwitch!
    @IBOutlet weak var precacheSwitch: UISwitch!
    @IBOutlet weak var forcePortraitSwitch: UISwitch!
    @IBOutlet weak var nightModeSwitch: UISwitch!
    @IBOutlet weak var matchSystemDarkModeSwitch: UISwitch!

    @IBOutlet weak var forumOrderCell: UITableViewCell!
    @IBOutlet weak var fontSizeCell: UITableViewCell!
    @IBOutlet weak var keepHistoryCell: UITableViewCell!
    @IBOutlet weak var imageCacheCell: UITableViewCell!

    @IBOutlet weak var iCloudSyncDetailLabel: UILabel!
    @IBOutlet weak var versionDetailLabel: UILabel!

    var bag = Set<AnyCancellable>()

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        forumOrderCell.textLabel?.text = NSLocalizedString("SettingsViewController.Forum_Order_Custom", comment: "Forum Order")

        let settings = AppEnvironment.current.settings
        displayImageSwitch.isOn = settings.displayImage.value
        forcePortraitSwitch.isOn = settings.forcePortraitForPhone.value
        removeTailsSwitch.isOn = settings.removeTails.value
        precacheSwitch.isOn = settings.precacheNextPage.value
        versionDetailLabel.text = applicationVersion()

        navigationItem.title = NSLocalizedString("SettingsViewController.NavigationBar_Title", comment: "Settings")

        fontSizeCell.textLabel?.text = NSLocalizedString("SettingsViewController.Font_Size", comment: "Font Size")
        fontSizeCell.detailTextLabel?.text = settings.defaults.string(forKey: "FontSize")
        fontSizeCell.selectionStyle = .blue
        fontSizeCell.accessoryType = .disclosureIndicator

        keepHistoryCell.textLabel?.text = NSLocalizedString("SettingsViewController.HistoryLimit", comment: "History Limit")
        keepHistoryCell.detailTextLabel?.text = historyLimitString(from: settings.defaults.integer(forKey: "HistoryLimit"))
        keepHistoryCell.selectionStyle = .blue
        keepHistoryCell.accessoryType = .disclosureIndicator

        let prettyPrintedCacheSize = Double(totalCacheSize() / (102 * 1024)) / 10.0
        imageCacheCell.detailTextLabel?.text = String(format: "%.1f MiB", prettyPrintedCacheSize)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceivePaletteChangeNotification),
            name: .APPaletteDidChange,
            object: nil
        )

        setupObservation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let settings = AppEnvironment.current.settings
        fontSizeDetailLabel.text = settings.defaults.string(forKey: "FontSize")
        keepHistoryCell.detailTextLabel?.text = historyLimitString(from: settings.defaults.integer(forKey: "HistoryLimit"))

        didReceivePaletteChangeNotification(nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Crashlytics.sharedInstance().setObjectValue("SettingsViewController", forKey: "lastViewController")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if AppEnvironment.current.settings.forcePortraitForPhone.value && UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return super.supportedInterfaceOrientations
        }
    }

    @IBAction func backAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        S1LogDebug("select: \(indexPath)")
        tableView.deselectRow(at: indexPath, animated: true)

        let settings = AppEnvironment.current.settings

        switch (indexPath.section, indexPath.row) {
        case (0, 2):
            let keys: [String] = {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    return ["15px", "17px", "19px"]
                } else {
                    return ["18px", "20px", "22px"]
                }
            }()

            let controller = GSSingleSelectionTableViewController(keys: keys, andSelectedKey: settings.defaults.string(forKey: "FontSize") ?? "")
            controller.title = NSLocalizedString("SettingsViewController.Font_Size", comment: "Font Size")
            controller.completionHandler = { value in
                settings.defaults.setValue(value, forKey: "FontSize")
            }
            navigationController?.pushViewController(controller, animated: true)
        case (0, 4):
            let selectedKey = settings.defaults.integer(forKey: "HistoryLimit")
            let keys = [
                NSLocalizedString("SettingsViewController.HistoryLimit.3days", comment: "3 days"),
                NSLocalizedString("SettingsViewController.HistoryLimit.1week", comment: "1 week"),
                NSLocalizedString("SettingsViewController.HistoryLimit.2weeks", comment: "2 weeks"),
                NSLocalizedString("SettingsViewController.HistoryLimit.1month", comment: "1 month"),
                NSLocalizedString("SettingsViewController.HistoryLimit.3months", comment: "3 months"),
                NSLocalizedString("SettingsViewController.HistoryLimit.6months", comment: "6 months"),
                NSLocalizedString("SettingsViewController.HistoryLimit.1year", comment: "1 year"),
                NSLocalizedString("SettingsViewController.HistoryLimit.Forever", comment: "Forever")
            ]

            let controller = GSSingleSelectionTableViewController(keys: keys, andSelectedKey: historyLimitString(from: selectedKey))
            controller.title = NSLocalizedString("SettingsViewController.HistoryLimit", comment: "HistoryLimit")
            controller.completionHandler = { [weak self] value in
                guard let strongSelf = self else { return }
                settings.defaults.setValue(strongSelf.parseHistoryLimitString(value), forKey: "HistoryLimit")
            }
            navigationController?.pushViewController(controller, animated: true)
        case (0, 0):
            present(LoginViewController(), animated: true, completion: nil)
        case (0, 10):
            URLCache.shared.removeAllCachedResponses()
            clearWebKitCache()

            let prettyPrintedCacheSize = Double(totalCacheSize() / (102 * 1024)) / 10.0
            imageCacheCell.detailTextLabel?.text = String(format: "%.1f MiB", prettyPrintedCacheSize)
        case (0, 11):
            navigationController?.pushViewController(AdvancedSettingsViewController(), animated: true)
        case (1, 0):
            navigationController?.pushViewController(CloudKitViewController(), animated: true)
        case (2, 2):
            #if DEBUG
            pushLogViewer()
            #else
            let safariViewController = SFSafariViewController(url: URL(string: "https://ainopara.github.io/stage1st-reader-EULA.html")!)
            self.present(safariViewController, animated: true, completion: nil)
            #endif
        case (2, 3):
            navigationController?.pushViewController(acknowledgementListViewController(), animated: true)
        default:
            break
        }
    }

    override func didReceivePaletteChangeNotification(_ notification: Notification?) {

        let colorManager = AppEnvironment.current.colorManager

        displayImageSwitch.onTintColor = colorManager.colorForKey("appearance.switch.tint")
        removeTailsSwitch.onTintColor = colorManager.colorForKey("appearance.switch.tint")
        precacheSwitch.onTintColor = colorManager.colorForKey("appearance.switch.tint")
        forcePortraitSwitch.onTintColor = colorManager.colorForKey("appearance.switch.tint")
        nightModeSwitch.onTintColor = colorManager.colorForKey("appearance.switch.tint")
        matchSystemDarkModeSwitch.onTintColor = colorManager.colorForKey("appearance.switch.tint")

        navigationController?.navigationBar.barStyle = colorManager.isDarkTheme() ? .black : .default
        navigationController?.navigationBar.barTintColor = colorManager.colorForKey("appearance.navigationbar.bartint")
        navigationController?.navigationBar.tintColor = colorManager.colorForKey("appearance.navigationbar.tint")
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: colorManager.colorForKey("appearance.navigationbar.title"),
            NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 17.0)
        ]
    }
}

extension SettingsViewController {
    func applicationVersion() -> String {
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
        if
            let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first,
            let libraryFolder = try? Folder(path: libraryURL.relativePath),
            let webKitCacheFolder = try? libraryFolder.subfolder(named: "Caches").subfolder(named: "WebKit")
        {
            for file in webKitCacheFolder.files.recursive {
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

        AppEnvironment.current.settings.currentUsername
            .map { currentUserName in
                return currentUserName ?? NSLocalizedString("SettingsViewController.Not_Login_State_Mark", comment: "")
            }
            .assign(to: \.text, on: usernameDetailLabel)
            .store(in: &bag)

        AppEnvironment.current.settings.manualControlInterfaceStyle
            .map { !$0 }
            .assign(to: \.isOn, on: matchSystemDarkModeSwitch)
            .store(in: &bag)

        AppEnvironment.current.settings.nightMode
            .assign(to: \.isOn, on: nightModeSwitch)
            .store(in: &bag)

        displayImageSwitch.publisher(for: .valueChanged)
            .map(\.isOn)
            .subscribe(AppEnvironment.current.settings.displayImage)
            .store(in: &bag)

        removeTailsSwitch.publisher(for: .valueChanged)
            .map(\.isOn)
            .subscribe(AppEnvironment.current.settings.removeTails)
            .store(in: &bag)

        precacheSwitch.publisher(for: .valueChanged)
            .map(\.isOn)
            .subscribe(AppEnvironment.current.settings.precacheNextPage)
            .store(in: &bag)

        nightModeSwitch.publisher(for: .valueChanged)
            .map(\.isOn)
            .subscribe(AppEnvironment.current.settings.nightMode)
            .store(in: &bag)

        forcePortraitSwitch.publisher(for: .valueChanged)
            .map(\.isOn)
            .subscribe(AppEnvironment.current.settings.forcePortraitForPhone)
            .store(in: &bag)

        matchSystemDarkModeSwitch.publisher(for: .valueChanged)
            .map(\.isOn)
            .map { !$0 }
            .subscribe(AppEnvironment.current.settings.manualControlInterfaceStyle)
            .store(in: &bag)

        NotificationCenter.default.reactive
            .notifications(forName: .YapDatabaseCloudKitSuspendCountChanged)
            .take(during: self.reactive.lifetime)
            .signal.observeValues { [weak self] (_) in
                self?.updateCloudKitStatus(
                    state: AppEnvironment.current.cloudkitManager.state.value,
                    enableSync: AppEnvironment.current.settings.enableCloudKitSync.value
                )
            }

        NotificationCenter.default.reactive
            .notifications(forName: .YapDatabaseCloudKitInFlightChangeSetChanged)
            .take(during: self.reactive.lifetime)
            .signal.observeValues { [weak self] (_) in
                self?.updateCloudKitStatus(
                    state: AppEnvironment.current.cloudkitManager.state.value,
                    enableSync: AppEnvironment.current.settings.enableCloudKitSync.value
                )
            }

        AppEnvironment.current.cloudkitManager.state
            .combineLatest(AppEnvironment.current.settings.enableCloudKitSync)
            .sink { [weak self] (args) in
                let (state, enableSync) = args
                self?.updateCloudKitStatus(state: state, enableSync: enableSync)
            }
            .store(in: &bag)
    }

    func updateCloudKitStatus(state: CloudKitManager.State, enableSync: Bool) {
        S1LogDebug("Observed CloudKit manager state changed.")
        DispatchQueue.main.async {
            guard enableSync else {
                self.iCloudSyncDetailLabel.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Off", comment: "Off")
                return
            }

            switch state {
            case .waitingSetupTriggered:
                self.iCloudSyncDetailLabel.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Off", comment: "Off")
//                self.iCloudSyncCell.detailTextLabel?.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Init", comment: "Init")
            case .migrating, .identifyUser, .createZone, .createZoneSubscription:
                self.iCloudSyncDetailLabel.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Setup", comment: "Setup")
            case .fetchRecordChanges:
                self.iCloudSyncDetailLabel.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Fetch", comment: "Fetch")
            case .readyForUpload:
                let suspendCount = AppEnvironment.current.databaseManager.cloudKitExtension.suspendCount
                let inFlightCount = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfInFlightChangeSets
                let queuedCount = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfQueuedChangeSets
                if suspendCount == 0 && inFlightCount == 0 && queuedCount == 0 {
                    self.iCloudSyncDetailLabel.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Ready", comment: "Ready")
                } else {
                    self.iCloudSyncDetailLabel.text =
                        NSLocalizedString("SettingsViewController.CloudKit.Status.Upload", comment: "Upload") + "(\(inFlightCount) - \(queuedCount))"
                }

            case .createZoneError, .createZoneSubscriptionError, .fetchRecordChangesError, .uploadError, .networkError:
                let suspendCount = AppEnvironment.current.databaseManager.cloudKitExtension.suspendCount
                self.iCloudSyncDetailLabel.text =
                    NSLocalizedString("SettingsViewController.CloudKit.Status.Recover", comment: "Recover") + "(\(suspendCount))"
            case .halt:
                self.iCloudSyncDetailLabel.text = NSLocalizedString("SettingsViewController.CloudKit.Status.Halt", comment: "Halt")
            }
        }
    }
}

private extension SettingsViewController {

    func parseHistoryLimitString(_ string: String) -> Int {
        switch string {
        case NSLocalizedString("SettingsViewController.HistoryLimit.3days", comment: ""):
            return 259200
        case NSLocalizedString("SettingsViewController.HistoryLimit.1week", comment: ""):
            return 604800
        case NSLocalizedString("SettingsViewController.HistoryLimit.2weeks", comment: ""):
            return 1209600
        case NSLocalizedString("SettingsViewController.HistoryLimit.1month", comment: ""):
            return 2592000
        case NSLocalizedString("SettingsViewController.HistoryLimit.3months", comment: ""):
            return 7884000
        case NSLocalizedString("SettingsViewController.HistoryLimit.6months", comment: ""):
            return 15768000
        case NSLocalizedString("SettingsViewController.HistoryLimit.1year", comment: ""):
            return 31536000
        default:
            return -1
        }
    }

    func historyLimitString(from value: Int) -> String {
        switch value {
        case 259200:
            return NSLocalizedString("SettingsViewController.HistoryLimit.3days", comment: "")
        case 604800:
            return NSLocalizedString("SettingsViewController.HistoryLimit.1week", comment: "")
        case 1209600:
            return NSLocalizedString("SettingsViewController.HistoryLimit.2weeks", comment: "")
        case 2592000:
            return NSLocalizedString("SettingsViewController.HistoryLimit.1month", comment: "")
        case 7884000:
            return NSLocalizedString("SettingsViewController.HistoryLimit.3months", comment: "")
        case 15768000:
            return NSLocalizedString("SettingsViewController.HistoryLimit.6months", comment: "")
        case 31536000:
            return NSLocalizedString("SettingsViewController.HistoryLimit.1year", comment: "")
        default:
            return NSLocalizedString("SettingsViewController.HistoryLimit.Forever", comment: "")
        }
    }
}
