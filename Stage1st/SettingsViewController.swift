//
//  SettingsViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//
import UIKit

extension S1SettingViewController {
    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .LightContent : .Default
    }
}

extension S1SettingViewController {
    func applicationVersion() -> String {
        guard let shortVersionString = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString"),
            let versionString = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion") else {
                return "?"
        }
        return "\(shortVersionString) (\(versionString))"
    }
}
