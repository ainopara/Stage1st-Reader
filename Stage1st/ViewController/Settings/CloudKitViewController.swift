//
//  CloudKitViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/4/20.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit
import QuickTableViewController
import YapDatabase

class CloudKitViewController: QuickTableViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTable()
    }

    func updateTable() {
        let iCloudSection = Section(
            title: NSLocalizedString("CloudKitViewController.iCloudSection.header", comment: ""),
            rows: [],
            footer: NSLocalizedString("CloudKitViewController.iCloudSection.footer", comment: "")
        )

        iCloudSection.rows.append(NavigationRow(
            title: NSLocalizedString("CloudKitViewController.AccountStatusRow.title", comment: ""),
            subtitle: Subtitle.rightAligned(AppEnvironment.current.cloudkitManager.accountStatus.value.debugDescription)
        ))

        iCloudSection.rows.append(SwitchRow(
            title: NSLocalizedString("CloudKitViewController.iCloudSwitchRow.title", comment: ""),
            switchValue: AppEnvironment.current.settings.enableCloudKitSync.value,
            action: { row in
                AppEnvironment.current.settings.enableCloudKitSync.value.toggle()
                if AppEnvironment.current.settings.enableCloudKitSync.value == false {
                    AppEnvironment.current.cloudkitManager.prepareForUnregister()
                    AppEnvironment.current.databaseManager.unregisterCloudKitExtension()
                }
            }
        ))

        let detailSection = Section(
            title: NSLocalizedString("CloudKitViewController.DetailSection.header", comment: ""),
            rows: []
        )

        detailSection.rows.append(NavigationRow(
            title: NSLocalizedString("CloudKitViewController.StateRow.title", comment: ""),
            subtitle: Subtitle.rightAligned(AppEnvironment.current.cloudkitManager.state.value.debugDescription)
        ))

        detailSection.rows.append(NavigationRow(
            title: NSLocalizedString("CloudKitViewController.SuspendCountRow.title", comment: ""),
            subtitle: Subtitle.rightAligned("\(AppEnvironment.current.databaseManager.cloudKitExtension.suspendCount)")
        ))

        let queued = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfQueuedChangeSets
        let inFlight = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfInFlightChangeSets
        detailSection.rows.append(NavigationRow(
            title: NSLocalizedString("CloudKitViewController.UploadQueueRow.title", comment: ""),
            subtitle: Subtitle.rightAligned("\(inFlight) - \(queued)"),
            action: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.navigationController?.pushViewController(CloudKitUploadQueueViewController(nibName: nil, bundle: nil), animated: true)
            }
        ))

        detailSection.rows.append(NavigationRow(
            title: NSLocalizedString("CloudKitViewController.ErrorsRow.title", comment: ""),
            subtitle: Subtitle.rightAligned("\(AppEnvironment.current.cloudkitManager.errors.count)"),
            action: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.navigationController?.pushViewController(CloudKitErrorListViewController(nibName: nil, bundle: nil), animated: true)
            }
        ))

        tableContents = [
            iCloudSection
        ]

        #if DEBUG
        tableContents.append(detailSection)
        #endif

        tableView.reloadData()
    }
}

class CloudKitUploadQueueViewController: UIViewController {
    let tableView = UITableView(frame: .zero, style: .grouped)

    var changeSets = [YDBCKChangeSet]()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        changeSets = AppEnvironment.current.cloudkitManager.cloudKitExtension.pendingChangeSets()

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100.0
        tableView.delegate = self
        tableView.dataSource = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }
    }
}

extension CloudKitUploadQueueViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return changeSets.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(changeSets[section].recordIDsToDeleteCount + changeSets[section].recordsToSaveCount)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.numberOfLines = 0
        let changeSet = changeSets[indexPath.section]
        if indexPath.row < changeSet.recordIDsToDeleteCount {
            let recordIDToDelete = changeSet.recordIDsToDelete[indexPath.row]
            cell.textLabel?.text = "Delete: \(recordIDToDelete.recordName)"
            return cell
        } else {
            let record = changeSet.recordsToSave[indexPath.row - Int(changeSet.recordIDsToDeleteCount)]
            cell.textLabel?.text = "Change: \(record)"
        }
        return cell
    }
}

extension CloudKitUploadQueueViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

class CloudKitUploadChangeSetViewController: UIViewController {

}

class CloudKitErrorListViewController: UIViewController {
    let tableView = UITableView(frame: .zero, style: .grouped)

    var errors: [S1CloudKitError] = []

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        errors = AppEnvironment.current.cloudkitManager.errors.reversed()

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100.0
        tableView.delegate = self
        tableView.dataSource = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }
    }
}

extension CloudKitErrorListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return errors.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "cell") {
            let error = errors[indexPath.row]
            configure(cell: cell, with: error)
            return cell
        } else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
            cell.textLabel?.numberOfLines = 0
            let error = errors[indexPath.row]
            configure(cell: cell, with: error)
            return cell
        }
    }

    func configure(cell: UITableViewCell, with cloudKitError: S1CloudKitError) {
        let prefix: String
        let underlyingError: Error
        switch cloudKitError {
        case let .createZoneError(error):
            prefix = "CreateZoneError: "
            underlyingError = error
        case let .createZoneSubscriptionError(error):
            prefix = "CreateZoneSubscriptionError: "
            underlyingError = error
        case let .fetchChangesError(error):
            prefix = "FetchChangesError: "
            underlyingError = error
        case let .uploadError(error):
            prefix = "UploadError: "
            underlyingError = error
        }

        if let ckError = underlyingError as? CKError {
            cell.textLabel?.text = "\(prefix)\(ckError.code) \(ckError.localizedDescription)"
        } else {
            cell.textLabel?.text = "\(prefix)\(underlyingError.localizedDescription)"
        }
    }
}

extension CloudKitErrorListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

class CloudKitErrorDetailViewController: UIViewController {

}

// MARK: -

extension Bool {
    mutating func toggle() {
        self = !self
    }
}
