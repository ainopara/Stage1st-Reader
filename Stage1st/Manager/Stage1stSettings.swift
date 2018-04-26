//
//  Stage1stSettings.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/4/26.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import ReactiveSwift

extension DefaultsKeys {
    static let currentUsername = DefaultsKey<String>("InLoginStateID")

    static let forumOrder = DefaultsKey<[[String]]>("Order")
    static let displayImage = DefaultsKey<Bool>("Display")
    static let removeTails = DefaultsKey<Bool>("RemoveTails")
    static let precacheNextPage = DefaultsKey<Bool>("PrecacheNextPage")
    static let forcePortraitForPhone = DefaultsKey<Bool>("ForcePortraitForPhone")
    static let nightMode = DefaultsKey<Bool>("NightMode")
    static let enableCloudKitSync = DefaultsKey<Bool>("EnableSync")
    static let historyLimit = DefaultsKey<Int>("HistoryLimit")

    static let reverseAction = DefaultsKey<Bool>("Stage1st_Content_ReverseFloorAction")
    static let hideStickTopics = DefaultsKey<Bool>("Stage1st_TopicList_HideStickTopics")

    static let previousWebKitCacheCleaningDate = DefaultsKey<Date>("PreviousWebKitCacheCleaningDate")
}

class Stage1stSettings: Settings {
    // Note: Initial value of MutablePropery will be overwrited by value in UserDefaults while binding.

    // Login
    let currentUsername: MutableProperty<String?> = MutableProperty(nil)

    // Settings
    let displayImage: MutableProperty<Bool> = MutableProperty(false)
    let removeTails: MutableProperty<Bool> = MutableProperty(false)
    let precacheNextPage: MutableProperty<Bool> = MutableProperty(false)
    let forcePortraitForPhone: MutableProperty<Bool> = MutableProperty(false)
    let nightMode: MutableProperty<Bool> = MutableProperty(false)
    let enableCloudKitSync: MutableProperty<Bool> = MutableProperty(false)
    let historyLimit: MutableProperty<Int> = MutableProperty(-1)
    let forumOrder: MutableProperty<[[String]]> = MutableProperty([[], []])

    // Advanced Settings
    let reverseAction: MutableProperty<Bool> = MutableProperty(false)
    let hideStickTopics: MutableProperty<Bool> = MutableProperty(false)

    // Cleaning
    let previousWebKitCacheCleaningDate: MutableProperty<Date?> = MutableProperty(nil)

    // MARK: -

    override init(defaults: UserDefaults = UserDefaults.standard) {
        super.init(defaults: defaults)

        // Login
        bind(property: currentUsername, to: .currentUsername)

        // Settings
        bind(property: displayImage, to: .displayImage, defaultValue: true)
        bind(property: removeTails, to: .removeTails, defaultValue: true)
        bind(property: precacheNextPage, to: .precacheNextPage, defaultValue: true)
        bind(property: forcePortraitForPhone, to: .forcePortraitForPhone, defaultValue: true)
        bind(property: nightMode, to: .nightMode, defaultValue: false)
        bind(property: enableCloudKitSync, to: .enableCloudKitSync, defaultValue: false)
        bind(property: historyLimit, to: .historyLimit, defaultValue: -1)
        bind(property: forumOrder, to: .forumOrder, defaultValue: [[], []])

        // Advanced Settings
        bind(property: reverseAction, to: .reverseAction, defaultValue: false)
        bind(property: hideStickTopics, to: .hideStickTopics, defaultValue: true)

        // Cleaning
        bind(property: previousWebKitCacheCleaningDate, to: .previousWebKitCacheCleaningDate)

        // Debug
        currentUsername.producer.startWithValues { (value) in
            S1LogDebug("Settings: currentUsername -> \(String(describing: value))")
        }
        displayImage.producer.startWithValues { (value) in
            S1LogDebug("Settings: displayImage -> \(String(describing: value))")
        }
        removeTails.producer.startWithValues { (value) in
            S1LogDebug("Settings: removeTails -> \(String(describing: value))")
        }
        precacheNextPage.producer.startWithValues { (value) in
            S1LogDebug("Settings: precacheNextPage -> \(String(describing: value))")
        }
        forcePortraitForPhone.producer.startWithValues { (value) in
            S1LogDebug("Settings: forcePortraitForPhone -> \(String(describing: value))")
        }
        nightMode.producer.startWithValues { (value) in
            S1LogDebug("Settings: nightMode -> \(String(describing: value))")
        }
        enableCloudKitSync.producer.startWithValues { (value) in
            S1LogDebug("Settings: enableCloudKitSync -> \(String(describing: value))")
        }
        historyLimit.producer.startWithValues { (value) in
            S1LogDebug("Settings: historyLimit -> \(String(describing: value))")
        }
        forumOrder.producer.startWithValues { (value) in
            S1LogDebug("Settings: forumOrder -> \(String(describing: value))")
        }
        reverseAction.producer.startWithValues { (value) in
            S1LogDebug("Settings: reverseAction -> \(String(describing: value))")
        }
        hideStickTopics.producer.startWithValues { (value) in
            S1LogDebug("Settings: hideStickTopics -> \(String(describing: value))")
        }
        previousWebKitCacheCleaningDate.producer.startWithValues { (value) in
            S1LogDebug("Settings: previousWebKitCacheCleaningDate -> \(String(describing: value))")
        }
    }
}
