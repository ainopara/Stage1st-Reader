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

        updateTable()
    }

    func updateTable() {
        tableContents = [
            Section(title: "Content", rows: [
                SwitchRow(title: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.title", comment: ""),
                          switchValue: UserDefaults.standard.bool(forKey: ReverseActionKey),
                          action: { (row) in
                    UserDefaults.standard.set((row as! SwitchRow).switchValue, forKey: ReverseActionKey)
                })
            ]),
            Section(title: "Topic List", rows: [
                SwitchRow(title: NSLocalizedString("AdvancedSettingsViewController.HideStickTopicsRow.title", comment: ""),
                          switchValue: UserDefaults.standard.bool(forKey: HideStickTopicsKey),
                          action: { (row) in
                    UserDefaults.standard.set((row as! SwitchRow).switchValue, forKey: HideStickTopicsKey)
                })
            ]),
            Section(title: "Reset", rows: [
                TapActionRow(title: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.title", comment: ""),
                             action: resetDefaultSettings)
            ])
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
