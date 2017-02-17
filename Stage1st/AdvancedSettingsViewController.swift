//
//  AdvancedSettingsViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 16/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import QuickTableViewController

let reverseActionKey = "Stage1st.Content.ReverseFloorAction"

final class AdvancedSettingsViewController: QuickTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        tableContents = [
            Section(title: "Content", rows: [
                SwitchRow(title: "Reverse Floor Action", switchValue: UserDefaults.standard.bool(forKey: reverseActionKey), action: { (row) in
                    UserDefaults.standard.set((row as! SwitchRow).switchValue, forKey: reverseActionKey)
                })
            ]),

            Section(title: "Reset", rows: [
                TapActionRow(title: "Reset Default Settings", action: resetDefaultSettings)
            ])
        ]
    }

    private func resetDefaultSettings(_ row: Row) {
        
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
