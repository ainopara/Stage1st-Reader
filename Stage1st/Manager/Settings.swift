//
//  Settings.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/4/17.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SwiftyUserDefaults
import ReactiveSwift
import ReactiveCocoa
import QuickTableViewController
import CrashlyticsLogger
import DeviceKit
import AlamofireImage

extension DefaultsKeys {

    static let cachedUsername = DefaultsKey<String?>("UserIDCached")
    static let currentUsername = DefaultsKey<String?>("InLoginStateID")

    static let displayImage = DefaultsKey<Bool>("Display")
    static let showsReplyIncrement = DefaultsKey<Bool>("ReplyIncrement")
    static let removeTails = DefaultsKey<Bool>("RemoveTails")
    static let precacheNextPage = DefaultsKey<Bool>("PrecacheNextPage")
    static let forcePortraitForPhone = DefaultsKey<Bool>("ForcePortraitForPhone")
    static let nightMode = DefaultsKey<Bool>("NightMode")
    static let enableCloudKitSync = DefaultsKey<Bool>("EnableSync")

    static let reverseAction = DefaultsKey<Bool>("Stage1st.Content.ReverseFloorAction")
    static let hideStickTopics = DefaultsKey<Bool>("Stage1st.TopicList.HideStickTopics")

    static let historyLimitKey = DefaultsKey<String>("HistoryLimit")
    static let previousWebKitCacheCleaningDateKey = DefaultsKey<Date?>("PreviousWebKitCacheCleaningDate")
}

class Settings {
    let defaults: UserDefaults

    // Note: Initial value of MutablePropery will be overwrited by value in UserDefaults while binding.

    // Settings
    let displayImage: MutableProperty<Bool> = MutableProperty(false)
    let showsReplyIncrement: MutableProperty<Bool> = MutableProperty(false)
    let removeTails: MutableProperty<Bool> = MutableProperty(false)
    let precacheNextPage: MutableProperty<Bool> = MutableProperty(false)
    let forcePortraitForPhone: MutableProperty<Bool> = MutableProperty(false)
    let nightMode: MutableProperty<Bool> = MutableProperty(false)
    let enableCloudKitSync: MutableProperty<Bool> = MutableProperty(false)

    // Advanced Settings
    let reverseAction: MutableProperty<Bool> = MutableProperty(false)
    let hideStickTopics: MutableProperty<Bool> = MutableProperty(false)

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults

        // Settings
        displayImage.bind(to: .displayImage, in: defaults)
        showsReplyIncrement.bind(to: .showsReplyIncrement, in: defaults)
        removeTails.bind(to: .removeTails, in: defaults)
        precacheNextPage.bind(to: .precacheNextPage, in: defaults)
        forcePortraitForPhone.bind(to: .forcePortraitForPhone, in: defaults)
        nightMode.bind(to: .nightMode, in: defaults)
        enableCloudKitSync.bind(to: .enableCloudKitSync, in: defaults)

        // Advanced Settings
        reverseAction.bind(to: .reverseAction, in: defaults)
        hideStickTopics.bind(to: .hideStickTopics, in: defaults)
    }
}

private extension MutableProperty where Value == Bool {
    func bind(to defaultKey: DefaultsKey<Bool>, in defaults: UserDefaults) {
        self.value = defaults[defaultKey]

        self.skipRepeats().signal.observeValues { (value) in
            guard defaults[defaultKey] != value else { return }
            defaults[defaultKey] = value
        }
    }
}

private extension MutableProperty where Value == Int? {
    func bind(to defaultKey: DefaultsKey<Int?>, in defaults: UserDefaults) {
        self.value = defaults[defaultKey]

        self.skipRepeats().signal.observeValues { (value) in
            guard defaults[defaultKey] != value else { return }
            defaults[defaultKey] = value
        }
    }
}

private extension MutableProperty where Value: Equatable {
    func bind(
        to defaultKey: DefaultsKey<Bool>,
        in defaults: UserDefaults,
        mapTo: @escaping (Value) -> Bool,
        mapFrom: @escaping (Bool) -> Value
        ) {
        self.value = mapFrom(defaults[defaultKey])

        self.skipRepeats().signal.observeValues { (value) in
            let mappedValue = mapTo(value)
            guard defaults[defaultKey] != mappedValue else { return }
            defaults[defaultKey] = mappedValue
        }
    }

    func bind(
        to defaultKey: DefaultsKey<Int?>,
        in defaults: UserDefaults,
        mapTo: @escaping (Value) -> Int?,
        mapFrom: @escaping (Int?) -> Value
        ) {
        self.value = mapFrom(defaults[defaultKey])

        self.skipRepeats().signal.observeValues { (value) in
            let mappedValue = mapTo(value)
            guard defaults[defaultKey] != mappedValue else { return }
            defaults[defaultKey] = mappedValue
        }
    }
}
