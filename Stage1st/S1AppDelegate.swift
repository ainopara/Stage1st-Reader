//
//  S1AppDelegate.swift
//  Stage1st
//
//  Created by Zheng Li on 4/4/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack

// MARK: Logging
extension S1AppDelegate {

    func setLogLevelForSwift() {
        #if DEBUG
            defaultDebugLevel = .verbose
        #else
            defaultDebugLevel = .info
        #endif
    }
}

// MARK: Migration
extension S1AppDelegate {

    func migrate() {
        migrateTo3800()
        migrateTo3900()
    }

    func migrateTo3800() {
        guard
            let orderForumArray = UserDefaults.standard.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
                DDLogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
                return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("真碉堡山") {
            UserDefaults.standard.set([displayForumArray, hiddenForumArray + ["真碉堡山"]], forKey: "Order")
        }
    }

    func migrateTo3900() {
        guard
            let orderForumArray = UserDefaults.standard.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
                DDLogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
                return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("DOTA") {
            UserDefaults.standard.set([displayForumArray, hiddenForumArray + ["DOTA", "欧美动漫"]], forKey: "Order")
        }
    }
}

// MARK: Setup
extension S1AppDelegate {

    func setup() {
        // NSCoding Mapping
        NSKeyedUnarchiver.setClass(Floor.self, forClassName: "S1Floor")

        // UserDefaults
        let userDefaults = UserDefaults.standard

        if userDefaults.value(forKey: "Order") == nil {
            let path = Bundle.main.path(forResource: "InitialOrder", ofType: "plist")!
            let orderArray = NSArray(contentsOfFile: path)
            userDefaults.set(orderArray, forKey: "Order")
        }

        if UI_USER_INTERFACE_IDIOM() == .pad {
            userDefaults.s1_setObjectIfNotExist(object: "18px", key: "FontSize")
        } else {
            userDefaults.s1_setObjectIfNotExist(object: "17px", key: "FontSize")
        }

        // TODO: Use register domain.
        userDefaults.s1_setObjectIfNotExist(object: "http://bbs.saraba1st.com/2b/", key: "BaseURL")
        userDefaults.s1_setObjectIfNotExist(object: NSNumber(value: -1), key: "HistoryLimit")
        userDefaults.s1_setObjectIfNotExist(object: true, key: "Display")
        userDefaults.s1_setObjectIfNotExist(object: true, key: "ReplyIncrement")
        userDefaults.s1_setObjectIfNotExist(object: true, key: "RemoveTails")
        userDefaults.s1_setObjectIfNotExist(object: true, key: "PrecacheNextPage")
        userDefaults.s1_setObjectIfNotExist(object: true, key: "ForcePortraitForPhone")
        userDefaults.s1_setObjectIfNotExist(object: false, key: "NightMode")
        userDefaults.s1_setObjectIfNotExist(object: false, key: "EnableSync")
    }
}

fileprivate extension UserDefaults {
    func s1_setObjectIfNotExist(object: Any, key: String) {
        if self.value(forKey: key) == nil {
            self.set(object, forKey: key)
        }
    }
}
