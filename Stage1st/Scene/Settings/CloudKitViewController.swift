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
import RxSwift

class CloudKitViewController: QuickTableViewController {

    private var bag = Set<AnyCancellable>()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dataSourceDidChanged),
            name: .YapDatabaseCloudKitSuspendCountChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dataSourceDidChanged),
            name: .YapDatabaseCloudKitInFlightChangeSetChanged,
            object: nil
        )

        AppEnvironment.current.cloudkitManager.state.sink { [weak self] (_) in
            self?.dataSourceDidChanged()
        }store(in: &bag)

        AppEnvironment.current.cloudkitManager.accountStatus.signal.observeValues { [weak self] (_) in
            self?.dataSourceDidChanged()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTable()
    }

    @objc func dataSourceDidChanged() {
        DispatchQueue.main.async {
            self.updateTable()
        }
    }

    func updateTable() {
        let iCloudSection = Section(
            title: NSLocalizedString("CloudKitViewController.iCloudSection.header", comment: ""),
            rows: [],
            footer: NSLocalizedString("CloudKitViewController.iCloudSection.footer", comment: "")
        )

        iCloudSection.rows.append(NavigationRow(
            text: NSLocalizedString("CloudKitViewController.AccountStatusRow.title", comment: ""),
            detailText: DetailText.value1(AppEnvironment.current.cloudkitManager.accountStatus.value.debugDescription)
        ))

        iCloudSection.rows.append(SwitchRow(
            text: NSLocalizedString("CloudKitViewController.iCloudSwitchRow.title", comment: ""),
            switchValue: AppEnvironment.current.settings.enableCloudKitSync.value,
            action: { [weak self] row in
                AppEnvironment.current.settings.enableCloudKitSync.value.toggle()
                if AppEnvironment.current.settings.enableCloudKitSync.value == false {
                    let title = NSLocalizedString("CloudKitViewController.iCloudSwitchRow.EnableMessage", comment: "")
                    let alertController = UIAlertController(title: title, message: "", preferredStyle: .alert)
                    self?.present(alertController, animated: true, completion: nil)
                    AppEnvironment.current.cloudkitManager.unregister {
                        DispatchQueue.main.async {
                            alertController.dismiss(animated: true, completion: nil)
                        }
                    }
                } else {
                    let title = NSLocalizedString("CloudKitViewController.iCloudSwitchRow.DisableMessage", comment: "")
                    let message = ""
                    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment: ""), style: .default, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                }
            }
        ))

        tableContents = [
            iCloudSection
        ]

        #if DEBUG
        let detailSection = Section(
            title: NSLocalizedString("CloudKitViewController.DetailSection.header", comment: ""),
            rows: []
        )

        detailSection.rows.append(NavigationRow(
            text: "Container ID",
            detailText: DetailText.value1(AppEnvironment.current.cloudkitManager.cloudKitContainer.containerIdentifier ?? "")
        ))

        detailSection.rows.append(NavigationRow(
            text: NSLocalizedString("CloudKitViewController.StateRow.title", comment: ""),
            detailText: DetailText.value1(AppEnvironment.current.cloudkitManager.state.value.debugDescription)
        ))

        detailSection.rows.append(NavigationRow(
            text: NSLocalizedString("CloudKitViewController.SuspendCountRow.title", comment: ""),
            detailText: DetailText.value1("\(AppEnvironment.current.databaseManager.cloudKitExtension.suspendCount)")
        ))

        let queued = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfQueuedChangeSets
        let inFlight = AppEnvironment.current.databaseManager.cloudKitExtension.numberOfInFlightChangeSets
        detailSection.rows.append(NavigationRow(
            text: NSLocalizedString("CloudKitViewController.UploadQueueRow.title", comment: ""),
            detailText: DetailText.value1("\(inFlight) - \(queued)"),
            action: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.navigationController?.pushViewController(CloudKitUploadQueueViewController(nibName: nil, bundle: nil), animated: true)
            }
        ))

        detailSection.rows.append(NavigationRow(
            text: NSLocalizedString("CloudKitViewController.ErrorsRow.title", comment: ""),
            detailText: DetailText.value1("\(AppEnvironment.current.cloudkitManager.errors.count)"),
            action: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.navigationController?.pushViewController(CloudKitErrorListViewController(nibName: nil, bundle: nil), animated: true)
            }
        ))

        tableContents.append(detailSection)
        #endif

        tableView.reloadData()
    }
}

class CloudKitUploadQueueViewController: UIViewController {
    let tableView = UITableView(frame: .zero, style: .insetGrouped)

    var changeSets = [YDBCKChangeSet]()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        changeSets = AppEnvironment.current.cloudkitManager.cloudKitExtension.pendingChangeSets()

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100.0
        tableView.delegate = self
        tableView.dataSource = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dataSourceDidChanged),
            name: .YapDatabaseCloudKitInFlightChangeSetChanged,
            object: nil
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }
    }

    @objc func dataSourceDidChanged() {
        changeSets = AppEnvironment.current.cloudkitManager.cloudKitExtension.pendingChangeSets()
        tableView.reloadData()
    }
}

extension CloudKitUploadQueueViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return changeSets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.numberOfLines = 0
        let changeSet = changeSets[indexPath.item]
        cell.textLabel?.text = "Deleted: \(changeSet.recordIDsToDeleteCount) Changed: \(changeSet.recordsToSaveCount)"
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
    let tableView = UITableView(frame: .zero, style: .insetGrouped)

    var errors: [S1CloudKitError] = []

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        errors = AppEnvironment.current.cloudkitManager.errors.reversed()

        tableView.rowHeight = UITableView.automaticDimension
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
            cell.textLabel?.text = "\(prefix)\(ckError.errorCode) \(ckError.localizedDescription)"
        } else {
            cell.textLabel?.text = "\(prefix)\(underlyingError)"
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
