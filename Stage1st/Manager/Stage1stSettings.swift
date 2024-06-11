//
//  Stage1stSettings.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/4/26.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Combine
import Ainoaibo

extension DefaultsKeys {
    static let currentUsername = DefaultsKey<String>("InLoginStateID")

    static let forumOrder = DefaultsKey<[[String]]>("Order")
    static let forumBundle = DefaultsKey<Data>("forumBundle")
    static let forumOrderV2 = DefaultsKey<[Int]>("forumOrderV2")
    static let displayImage = DefaultsKey<Bool>("Display")
    static let removeTails = DefaultsKey<Bool>("RemoveTails")
    static let precacheNextPage = DefaultsKey<Bool>("PrecacheNextPage")
    static let forcePortraitForPhone = DefaultsKey<Bool>("ForcePortraitForPhone")
    static let nightMode = DefaultsKey<Bool>("NightMode")
    static let manualControlInterfaceStyle = DefaultsKey<Bool>("manualControlInterfaceStyle")
    static let enableCloudKitSync = DefaultsKey<Bool>("EnableSync")
    static let historyLimit = DefaultsKey<Int>("HistoryLimit")

    static let reverseAction = DefaultsKey<Bool>("Stage1st_Content_ReverseFloorAction")
    static let hideStickTopics = DefaultsKey<Bool>("Stage1st_TopicList_HideStickTopics")
    static let shareWithoutImage = DefaultsKey<Bool>("ShareWithoutImage")
    static let tapticFeedbackForForumSwitch = DefaultsKey<Bool>("TapticFeedbackForForumSwitch")
    static let gestureControledNightModeSwitch = DefaultsKey<Bool>("gestureControledNightModeSwitch")
    static let enableOpenPasteboardLink = DefaultsKey<Bool>("enableOpenPasteboardLink")

    static let previousWebKitCacheCleaningDate = DefaultsKey<Date>("PreviousWebKitCacheCleaningDate")
    static let lastDailyTaskDate = DefaultsKey<[String: Date]>("lastDailyTaskDate")
    static let postPerPage = DefaultsKey<Int>("postPerPage")
}

class Stage1stSettings: DefaultsBasedSettings {
    // Note: Initial value of MutablePropery will be overwrited by value in UserDefaults while binding.

    // Login
    let currentUsername: CurrentValueSubject<String?, Never> = CurrentValueSubject(nil)

    // Settings
    let displayImage: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let removeTails: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let precacheNextPage: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let forcePortraitForPhone: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let nightMode: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let manualControlInterfaceStyle: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let enableCloudKitSync: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let historyLimit: CurrentValueSubject<Int, Never> = CurrentValueSubject(-1)
    let forumOrder: CurrentValueSubject<[[String]], Never> = CurrentValueSubject([[], []])
    let forumBundle: CurrentValueSubject<Data, Never> = CurrentValueSubject(Data())
    let forumOrderV2: CurrentValueSubject<[Int], Never> = CurrentValueSubject([])

    // Advanced Settings
    let reverseAction: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let hideStickTopics: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let shareWithoutImage: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let tapticFeedbackForForumSwitch: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let gestureControledNightModeSwitch: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let enableOpenPasteboardLink: CurrentValueSubject<Bool, Never> = CurrentValueSubject(true)
    let postPerPage: CurrentValueSubject<Int, Never> = CurrentValueSubject(40)

    // Cleaning
    let previousWebKitCacheCleaningDate: CurrentValueSubject<Date?, Never> = CurrentValueSubject(nil)
    let lastDailyTaskDate: CurrentValueSubject<[String: Date], Never> = CurrentValueSubject([:])

    private var bag = Set<AnyCancellable>()

    // MARK: -

    override init(defaults: UserDefaults = UserDefaults.standard) {
        super.init(defaults: defaults)

        bind(property: forumOrderV2, to: .forumOrderV2, defaultValue: [
            75, 6, 4, 51, 48, 50, 31, 77
        ])
        bind(property: forumBundle, to: .forumBundle, defaultValue: """
        {
          "date": 605274000,
          "forums": [
            {
              "id": 4,
              "name": "游戏论坛"
            },
            {
              "id": 6,
              "name": "动漫论坛"
            },
            {
              "id": 23,
              "name": "火星里侧"
            },
            {
              "id": 24,
              "name": "音乐论坛"
            },
            {
              "id": 27,
              "name": "内野"
            },
            {
              "id": 31,
              "name": "彼岸文化"
            },
            {
              "id": 48,
              "name": "影视论坛"
            },
            {
              "id": 50,
              "name": "文史沙龙"
            },
            {
              "id": 51,
              "name": "ＰＣ数码"
            },
            {
              "id": 53,
              "name": "魔兽世界"
            },
            {
              "id": 60,
              "name": "激战2"
            },
            {
              "id": 69,
              "name": "怪物猎人"
            },
            {
              "id": 74,
              "name": "马叉虫"
            },
            {
              "id": 75,
              "name": "卓明谷"
            },
            {
              "id": 76,
              "name": "车欠女未"
            },
            {
              "id": 77,
              "name": "八卦体育"
            },
            {
              "id": 80,
              "name": "摄影区"
            },
            {
              "id": 83,
              "name": "动漫投票"
            },
            {
              "id": 93,
              "name": "火暴"
            },
            {
              "id": 101,
              "name": "犭苗犭句"
            },
            {
              "id": 109,
              "name": "菠菜"
            },
            {
              "id": 111,
              "name": "英雄联盟"
            },
            {
              "id": 115,
              "name": "二手交易区"
            },
            {
              "id": 118,
              "name": "真碉堡山"
            },
            {
              "id": 123,
              "name": "吃货"
            },
            {
              "id": 124,
              "name": "开箱区"
            },
            {
              "id": 131,
              "name": "车"
            },
            {
              "id": 132,
              "name": "炉石传说"
            },
            {
              "id": 133,
              "name": "剑灵"
            },
            {
              "id": 134,
              "name": "热血魔兽"
            },
            {
              "id": 135,
              "name": "手游页游"
            },
            {
              "id": 136,
              "name": "模玩专区"
            },
            {
              "id": 138,
              "name": "DOTA"
            },
            {
              "id": 144,
              "name": "欧美动漫"
            },
            {
              "id": 151,
              "name": "虚拟主播VTB"
            },
            {
              "id": 156,
              "name": "二游格斗"
            }
          ]
        }
        """.data(using: .utf8) ?? Data())

        // Login
        bind(property: currentUsername, to: .currentUsername)

        // Settings
        bind(property: displayImage, to: .displayImage, defaultValue: true)
        bind(property: removeTails, to: .removeTails, defaultValue: true)
        bind(property: precacheNextPage, to: .precacheNextPage, defaultValue: true)
        bind(property: forcePortraitForPhone, to: .forcePortraitForPhone, defaultValue: true)
        bind(property: nightMode, to: .nightMode, defaultValue: false)
        bind(property: manualControlInterfaceStyle, to: .manualControlInterfaceStyle, defaultValue: false)
        bind(property: enableCloudKitSync, to: .enableCloudKitSync, defaultValue: false)
        bind(property: historyLimit, to: .historyLimit, defaultValue: -1)
        bind(property: forumOrder, to: .forumOrder, defaultValue: [[], []])

        // Advanced Settings
        bind(property: reverseAction, to: .reverseAction, defaultValue: false)
        bind(property: hideStickTopics, to: .hideStickTopics, defaultValue: true)
        bind(property: shareWithoutImage, to: .shareWithoutImage, defaultValue: false)
        bind(property: tapticFeedbackForForumSwitch, to: .tapticFeedbackForForumSwitch, defaultValue: false)
        bind(property: gestureControledNightModeSwitch, to: .gestureControledNightModeSwitch, defaultValue: true)
        bind(property: enableOpenPasteboardLink, to: .enableOpenPasteboardLink, defaultValue: true)
        bind(property: postPerPage, to: .postPerPage, defaultValue: 40)

        // Cleaning
        bind(property: previousWebKitCacheCleaningDate, to: .previousWebKitCacheCleaningDate)

        // DailyTask
        bind(property: lastDailyTaskDate, to: .lastDailyTaskDate, defaultValue: [:])

        // Debug
        currentUsername.sink { (value) in
            S1LogDebug("Settings: currentUsername -> \(String(describing: value))")
        }.store(in: &bag)
        displayImage.sink { (value) in
            S1LogDebug("Settings: displayImage -> \(String(describing: value))")
        }.store(in: &bag)
        removeTails.sink { (value) in
            S1LogDebug("Settings: removeTails -> \(String(describing: value))")
        }.store(in: &bag)
        precacheNextPage.sink { (value) in
            S1LogDebug("Settings: precacheNextPage -> \(String(describing: value))")
        }.store(in: &bag)
        forcePortraitForPhone.sink { (value) in
            S1LogDebug("Settings: forcePortraitForPhone -> \(String(describing: value))")
        }.store(in: &bag)
        nightMode.sink { (value) in
            S1LogDebug("Settings: nightMode -> \(String(describing: value))")
        }.store(in: &bag)
        enableCloudKitSync.sink { (value) in
            S1LogDebug("Settings: enableCloudKitSync -> \(String(describing: value))")
        }.store(in: &bag)
        historyLimit.sink { (value) in
            S1LogDebug("Settings: historyLimit -> \(String(describing: value))")
        }.store(in: &bag)
        forumOrder.sink { (value) in
            S1LogDebug("Settings: forumOrder -> \(String(describing: value))")
        }.store(in: &bag)
        reverseAction.sink { (value) in
            S1LogDebug("Settings: reverseAction -> \(String(describing: value))")
        }.store(in: &bag)
        hideStickTopics.sink { (value) in
            S1LogDebug("Settings: hideStickTopics -> \(String(describing: value))")
        }.store(in: &bag)
        shareWithoutImage.sink { (value) in
            S1LogDebug("Settings: shareWithoutImage -> \(String(describing: value))")
        }.store(in: &bag)
        tapticFeedbackForForumSwitch.sink { (value) in
            S1LogDebug("Settings: tapticFeedbackForForumSwitch -> \(String(describing: value))")
        }.store(in: &bag)
        gestureControledNightModeSwitch.sink { (value) in
            S1LogDebug("Settings: gestureControledNightModeSwitch -> \(String(describing: value))")
        }.store(in: &bag)
        previousWebKitCacheCleaningDate.sink { (value) in
            S1LogDebug("Settings: previousWebKitCacheCleaningDate -> \(String(describing: value))")
        }.store(in: &bag)
        lastDailyTaskDate.sink { (value) in
            S1LogDebug("Settings: lastDailyTaskDate -> \(String(describing: value))")
        }.store(in: &bag)
        enableOpenPasteboardLink.sink { (value) in
            S1LogDebug("Settings: enableOpenPasteboardLink -> \(String(describing: value))")
        }.store(in: &bag)
        postPerPage.sink { (value) in
            S1LogDebug("Settings: postPerPage -> \(String(describing: value))")
        }.store(in: &bag)
    }
}
