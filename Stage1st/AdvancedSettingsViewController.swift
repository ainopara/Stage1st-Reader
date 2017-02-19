//
//  AdvancedSettingsViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 16/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import QuickTableViewController
// swiftlint:disable variable_name
let ReverseActionKey = "Stage1st.Content.ReverseFloorAction"
let HideStickTopicsKey = "Stage1st.TopicList.HideStickTopics"
// swiftlint:enable variable_name
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
                          switchValue: UserDefaults.standard.bool(forKey: HideStickTopicsKey),
                          action: { (row) in
                    UserDefaults.standard.set((row as! SwitchRow).switchValue, forKey: HideStickTopicsKey)
                })
                ], footer: NSLocalizedString("AdvancedSettingsViewController.HideStickTopicsRow.footer", comment: "")),

            Section(title: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.header", comment: ""), rows: [
                SwitchRow(title: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.title", comment: ""),
                          switchValue: UserDefaults.standard.bool(forKey: ReverseActionKey),
                          action: { (row) in
                    UserDefaults.standard.set((row as! SwitchRow).switchValue, forKey: ReverseActionKey)
                })
                ], footer: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.footer", comment: "")),

            Section(title: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.header", comment: ""), rows: [
                TapActionRow(title: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.title", comment: ""),
                             action: resetDefaultSettings)
            ], footer: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.footer", comment: ""))
        ]
        tableView.reloadData()
    }

    private func resetDefaultSettings(_ row: Row) {
        UserDefaults.standard.removeObject(forKey: ReverseActionKey)
        UserDefaults.standard.removeObject(forKey: HideStickTopicsKey)
        updateTable()
    }
}

final class DebugViewController: QuickTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        tableContents = [
            Section(title: "Logging", rows: [
                TapActionRow(title: "Logs", action: showLoggingViewController)
            ])
        ]
    }

    private func showLoggingViewController(_ row: Row) {
        
    }
}
