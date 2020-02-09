//
//  AppDelegate+Migration.swift
//  Stage1st
//
//  Created by Zheng Li on 2020/2/9.
//  Copyright © 2020 Renaissance. All rights reserved.
//

import Foundation

extension AppDelegate {

    @objc func migrate() {
        migrateTo3_7()
        migrateTo3_8()
        migrateTo3_9()
        migrateTo3_9_4()
        migrateTo3_12_2()
        migrateTo3_14()
    }

    private func migrateTo3_7() {
        let userDefaults = AppEnvironment.current.settings.defaults
        if UIDevice.current.userInterfaceIdiom == .pad && userDefaults.object(forKey: "FontSize") as? String == "17px" {
            userDefaults.set("18px", forKey: "FontSize")
        }
    }

    private func migrateTo3_8() {
        let userDefaults = AppEnvironment.current.settings.defaults
        guard
            let orderForumArray = userDefaults.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("真碉堡山") {
            userDefaults.set([displayForumArray, hiddenForumArray + ["真碉堡山"]], forKey: "Order")
        }
    }

    private func migrateTo3_9() {
        let userDefaults = AppEnvironment.current.settings.defaults
        guard
            let orderForumArray = userDefaults.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else
        {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("DOTA") {
            userDefaults.set([displayForumArray, hiddenForumArray + ["DOTA", "欧美动漫"]], forKey: "Order")
        }
    }

    private func migrateTo3_9_4() {
        let userDefaults = AppEnvironment.current.settings.defaults
        guard
            let orderForumArray = userDefaults.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else
        {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("泥潭") {
            userDefaults.set([displayForumArray, hiddenForumArray + ["泥潭"]], forKey: "Order")
        }
    }

    private func migrateTo3_12_2() {
        let cacheDatabaseManager = AppEnvironment.current.cacheDatabaseManager
        let mahjongFaceItems = cacheDatabaseManager.mahjongFaceHistoryV2().map { item in MahjongFaceInputView.HistoryItem(id: item.key) }
        cacheDatabaseManager.set(mahjongFaceHistory: cacheDatabaseManager.mahjongFaceHistory() + mahjongFaceItems)
        cacheDatabaseManager.set(mahjongFaceHistoryV2: [])
    }

    private func migrateTo3_14() {
        let userDefaults = AppEnvironment.current.settings.defaults
        guard
            let orderForumArray = userDefaults.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2
        else {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }

        var displayForumArray = orderForumArray[0]
        var hiddenForumArray = orderForumArray[1]

        if !(displayForumArray + hiddenForumArray).contains("卓明谷") {
            displayForumArray = displayForumArray.map {
                if $0 == "外野" {
                    return "卓明谷"
                } else {
                    return $0
                }
            }

            hiddenForumArray = hiddenForumArray.map {
                if $0 == "外野" {
                    return "卓明谷"
                } else {
                    return $0
                }
            }
            userDefaults.set([displayForumArray, hiddenForumArray + ["火星里侧", "菠菜"]], forKey: "Order")
        }
    }
}
