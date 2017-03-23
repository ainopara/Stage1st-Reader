//
//  AdvancedSettingsViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 16/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import QuickTableViewController

final class AdvancedSettingsViewController: QuickTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTable()
    }

    func updateTable() {
        tableContents = [
            Section(title: NSLocalizedString("AdvancedSettingsViewController.HideStickTopicsRow.header", comment: ""), rows: [
                SwitchRow(title: NSLocalizedString("AdvancedSettingsViewController.HideStickTopicsRow.title", comment: ""),
                          switchValue: UserDefaults.standard.bool(forKey: Constants.defaults.hideStickTopicsKey),
                          action: { row in
                              UserDefaults.standard.set((row as! SwitchRow).switchValue, forKey: Constants.defaults.hideStickTopicsKey)
                }),
            ], footer: NSLocalizedString("AdvancedSettingsViewController.HideStickTopicsRow.footer", comment: "")),

            Section(title: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.header", comment: ""), rows: [
                SwitchRow(title: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.title", comment: ""),
                          switchValue: UserDefaults.standard.bool(forKey: Constants.defaults.reverseActionKey),
                          action: { row in
                              UserDefaults.standard.set((row as! SwitchRow).switchValue, forKey: Constants.defaults.reverseActionKey)
                }),
            ], footer: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.footer", comment: "")),

            Section(title: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.header", comment: ""), rows: [
                TapActionRow(title: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.title", comment: ""),
                             action: resetDefaultSettings),
            ], footer: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.footer", comment: "")),
        ]
        tableView.reloadData()
    }

    private func resetDefaultSettings(_: Row) {
        UserDefaults.standard.removeObject(forKey: Constants.defaults.reverseActionKey)
        UserDefaults.standard.removeObject(forKey: Constants.defaults.hideStickTopicsKey)
        updateTable()
    }
}

final class DebugViewController: QuickTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        tableContents = [
            Section(title: "Logging", rows: [
                TapActionRow(title: "Logs", action: showLoggingViewController),
            ]),
        ]
    }

    private func showLoggingViewController(_: Row) {
    }
}
