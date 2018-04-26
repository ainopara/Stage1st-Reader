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
        let settings = AppEnvironment.current.settings

        let hideStickTopicsSection = Section(
            title: NSLocalizedString("AdvancedSettingsViewController.HideStickTopicsRow.header", comment: ""),
            rows: [],
            footer: NSLocalizedString("AdvancedSettingsViewController.HideStickTopicsRow.footer", comment: "")
        )

        hideStickTopicsSection.rows.append(SwitchRow(
            title: NSLocalizedString("AdvancedSettingsViewController.HideStickTopicsRow.title", comment: ""),
            switchValue: settings.hideStickTopics.value,
            action: { row in settings.hideStickTopics.value = (row as! SwitchRow).switchValue }
        ))

        let reverseFloorSection = Section(
            title: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.header", comment: ""),
            rows: [],
            footer: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.footer", comment: "")
        )

        reverseFloorSection.rows.append(SwitchRow(
            title: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.title", comment: ""),
            switchValue: UserDefaults.standard.bool(forKey: Constants.defaults.reverseActionKey),
            action: { row in settings.reverseAction.value = (row as! SwitchRow).switchValue }
        ))

        let resetSection = Section(
            title: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.header", comment: ""),
            rows: [],
            footer: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.footer", comment: "")
        )

        resetSection.rows.append(TapActionRow(
            title: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.title", comment: ""),
            action: { [weak self] row in self?.resetDefaultSettings(row) }
        ))

        tableContents = [
            hideStickTopicsSection,
            reverseFloorSection,
            resetSection
        ]
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
