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
            text: NSLocalizedString("AdvancedSettingsViewController.HideStickTopicsRow.title", comment: ""),
            switchValue: settings.hideStickTopics.value,
            action: { row in settings.hideStickTopics.value = (row as! SwitchRow).switchValue }
        ))

        let reverseFloorSection = Section(
            title: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.header", comment: ""),
            rows: [],
            footer: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.footer", comment: "")
        )

        reverseFloorSection.rows.append(SwitchRow(
            text: NSLocalizedString("AdvancedSettingsViewController.ReverseFloorActionRow.title", comment: ""),
            switchValue: settings.reverseAction.value,
            action: { row in settings.reverseAction.value = (row as! SwitchRow).switchValue }
        ))

        let shareWithoutImageSection = Section(
            title: NSLocalizedString("AdvancedSettingsViewController.ShareWithoutImageRow.header", comment: ""),
            rows: [],
            footer: ""
        )

        shareWithoutImageSection.rows.append(SwitchRow(
            text: NSLocalizedString("AdvancedSettingsViewController.ShareWithoutImageRow.title", comment: ""),
            switchValue: settings.shareWithoutImage.value,
            action: { row in settings.shareWithoutImage.value = (row as! SwitchRow).switchValue }
        ))

        let tapticFeedbackSection = Section(
            title: NSLocalizedString("AdvancedSettingsViewController.TapticFeedbackRow.header", comment: ""),
            rows: [],
            footer: ""
        )

        tapticFeedbackSection.rows.append(SwitchRow(
            text: NSLocalizedString("AdvancedSettingsViewController.TapticFeedbackRow.title", comment: ""),
            switchValue: settings.tapticFeedbackForForumSwitch.value,
            action: { row in settings.tapticFeedbackForForumSwitch.value = (row as! SwitchRow).switchValue }
        ))

        let nightNodeGestureSection = Section(
            title: NSLocalizedString("AdvancedSettingsViewController.NightNodeGestureRow.header", comment: ""),
            rows: [],
            footer: ""
        )

        nightNodeGestureSection.rows.append(SwitchRow(
            text: NSLocalizedString("AdvancedSettingsViewController.NightNodeGestureRow.title", comment: ""),
            switchValue: settings.gestureControledNightModeSwitch.value,
            action: { row in settings.gestureControledNightModeSwitch.value = (row as! SwitchRow).switchValue }
        ))

        let openPasteboardSection = Section(
            title: NSLocalizedString("AdvancedSettingsViewController.OpenPasteboardRow.header", comment: ""),
            rows: [
                SwitchRow(
                    text: NSLocalizedString("AdvancedSettingsViewController.OpenPasteboardRow.title", comment: ""),
                    switchValue: settings.enableOpenPasteboardLink.value,
                    action: { row in settings.enableOpenPasteboardLink.value = (row as! SwitchRow).switchValue }
                )
            ],
            footer: ""
        )

        let resetSection = Section(
            title: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.header", comment: ""),
            rows: [],
            footer: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.footer", comment: "")
        )

        resetSection.rows.append(TapActionRow(
            text: NSLocalizedString("AdvancedSettingsViewController.ResetSettingsRow.title", comment: ""),
            action: { [weak self] row in self?.resetDefaultSettings(row) }
        ))

        tableContents = [
            hideStickTopicsSection,
            reverseFloorSection,
            shareWithoutImageSection,
            tapticFeedbackSection,
            nightNodeGestureSection,
            openPasteboardSection,
            resetSection
        ]
    }

    private func resetDefaultSettings(_: Row) {
        let settings = AppEnvironment.current.settings
        settings.removeValue(for: .reverseAction)
        settings.removeValue(for: .hideStickTopics)
        settings.removeValue(for: .shareWithoutImage)
        settings.removeValue(for: .tapticFeedbackForForumSwitch)
        settings.removeValue(for: .gestureControledNightModeSwitch)
        updateTable()
    }
}

final class DebugViewController: QuickTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        tableContents = [
            Section(title: "Logging", rows: [
                TapActionRow(text: "Logs", action: showLoggingViewController),
            ]),
        ]
    }

    private func showLoggingViewController(_: Row) {
    }
}
