//
//  AppDelegate+Migration.swift
//  Stage1st
//
//  Created by Zheng Li on 2020/2/9.
//  Copyright © 2020 Renaissance. All rights reserved.
//

import Foundation

extension AppDelegate {

    func migrate() {
        migrateTo3_7()
        migrateTo3_12_2()
        migrateTo3_16()
    }

    private func migrateTo3_7() {
        let userDefaults = AppEnvironment.current.settings.defaults
        if UIDevice.current.userInterfaceIdiom == .pad && userDefaults.object(forKey: "FontSize") as? String == "17px" {
            userDefaults.set("18px", forKey: "FontSize")
        }
    }

    private func migrateTo3_12_2() {
        let cacheDatabaseManager = AppEnvironment.current.cacheDatabaseManager
        let mahjongFaceItems = cacheDatabaseManager.mahjongFaceHistoryV2().map { item in MahjongFaceInputView.HistoryItem(id: item.key) }
        cacheDatabaseManager.set(mahjongFaceHistory: cacheDatabaseManager.mahjongFaceHistory() + mahjongFaceItems)
        cacheDatabaseManager.set(mahjongFaceHistoryV2: [])
    }

    private func migrateTo3_16() {
        let userDefaults = AppEnvironment.current.settings.defaults

        guard
            let orderForumArray = userDefaults.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2
        else {
            S1LogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }

        let displayForumArray = orderForumArray[0]
        guard !displayForumArray.isEmpty else { return }
        guard let data = userDefaults.data(forKey: "forumBundle") else { return }
        guard let bundle = try? JSONDecoder().decode(ForumBundle.self, from: data) else { return }
        let forums = displayForumArray.compactMap { name in bundle.forums.first(where: { $0.name == name }) }
        AppEnvironment.current.settings.forumOrderV2.value = forums.map { $0.id }
        userDefaults.removeObject(forKey: "Order")
    }
}
