//
//  SettingsViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//
import UIKit
import AcknowList
import WebKit
import CocoaLumberjack

extension SettingsViewController {
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return ColorManager.shared.isDarkTheme() ? .lightContent : .default
    }
}

extension SettingsViewController {
    @objc func applicationVersion() -> String {
        guard
            let shortVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString"),
            let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") else {
            return "?"
        }
        return "\(shortVersionString) (\(versionString))"
    }
}

extension SettingsViewController {
    @objc func acknowledgementListViewController() -> AcknowListViewController {
        let acknowledgmentPlistFilePath = Bundle.main.path(forResource: "Pods-Stage1st-acknowledgements", ofType: "plist")
        return AcknowListViewController(acknowledgementsPlistPath: acknowledgmentPlistFilePath)
    }

    @objc func clearWebKitCache() {
        let websiteDataTypes = Set([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])

        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: Date.distantPast) {
            DDLogInfo("WebKit disk cache cleaned.")
            UserDefaults.standard.set(Date(), forKey: Constants.defaults.previousWebKitCacheCleaningDateKey)
        }
    }
}
