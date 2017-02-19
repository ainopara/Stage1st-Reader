//
//  AdvancedSettingsViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 16/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import QuickTableViewController

let ReverseActionKey = "Stage1st.Content.ReverseFloorAction"
let HideStickTopicsKey = "Stage1st.TopicList.HideStickTopics"

final class AdvancedSettingsViewController: QuickTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        updateTable()
    }

    func updateTable() {
        tableContents = [
            Section(title: "Content", rows: [
                SwitchRow(title: "Reverse Floor Action", switchValue: UserDefaults.standard.bool(forKey: ReverseActionKey), action: { (row) in
                    UserDefaults.standard.set((row as! SwitchRow).switchValue, forKey: ReverseActionKey)
                })
            ]),
            Section(title: "Topic List", rows: [
                SwitchRow(title: "Hide Stick Topics", switchValue: UserDefaults.standard.bool(forKey: HideStickTopicsKey), action: { (row) in
                    UserDefaults.standard.set((row as! SwitchRow).switchValue, forKey: HideStickTopicsKey)
                })
            ]),
            Section(title: "Reset", rows: [
                TapActionRow(title: "Reset Default Settings", action: resetDefaultSettings)
            ])
        ]
        tableView.reloadData()
    }

    private func resetDefaultSettings(_ row: Row) {
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
