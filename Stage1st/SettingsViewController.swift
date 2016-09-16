//
//  SettingsViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//
import UIKit

extension SettingsViewController {
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .lightContent : .default
    }
}

extension SettingsViewController {
    func applicationVersion() -> String {
        guard
            let shortVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString"),
            let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") else {
                return "?"
        }
        return "\(shortVersionString) (\(versionString))"
    }
}
