//
//  Stage1stSettings.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/4/26.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import RxSwift
import Combine
import Ainoaibo

extension DefaultsKeys {
    static let currentUsername = DefaultsKey<String>("InLoginStateID")

    static let forumOrder = DefaultsKey<[[String]]>("Order")
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

    static let previousWebKitCacheCleaningDate = DefaultsKey<Date>("PreviousWebKitCacheCleaningDate")
    static let lastDailyTaskDate = DefaultsKey<Date>("lastDailyTaskDate")
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

    // Advanced Settings
    let reverseAction: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let hideStickTopics: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let shareWithoutImage: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let tapticFeedbackForForumSwitch: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let gestureControledNightModeSwitch: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)

    // Cleaning
    let previousWebKitCacheCleaningDate: CurrentValueSubject<Date?, Never> = CurrentValueSubject(nil)
    let lastDailyTaskDate: CurrentValueSubject<Date, Never> = CurrentValueSubject(.distantPast)

    private let bag = DisposeBag()

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

        // Cleaning
        bind(property: previousWebKitCacheCleaningDate, to: .previousWebKitCacheCleaningDate)

        // DailyTask
        bind(property: lastDailyTaskDate, to: .lastDailyTaskDate, defaultValue: .distantPast)

        // Debug
        currentUsername.sink { (value) in
            S1LogDebug("Settings: currentUsername -> \(String(describing: value))")
        }.disposed(by: bag)
        displayImage.sink { (value) in
            S1LogDebug("Settings: displayImage -> \(String(describing: value))")
        }.disposed(by: bag)
        removeTails.sink { (value) in
            S1LogDebug("Settings: removeTails -> \(String(describing: value))")
        }.disposed(by: bag)
        precacheNextPage.sink { (value) in
            S1LogDebug("Settings: precacheNextPage -> \(String(describing: value))")
        }.disposed(by: bag)
        forcePortraitForPhone.sink { (value) in
            S1LogDebug("Settings: forcePortraitForPhone -> \(String(describing: value))")
        }.disposed(by: bag)
        nightMode.sink { (value) in
            S1LogDebug("Settings: nightMode -> \(String(describing: value))")
        }.disposed(by: bag)
        enableCloudKitSync.sink { (value) in
            S1LogDebug("Settings: enableCloudKitSync -> \(String(describing: value))")
        }.disposed(by: bag)
        historyLimit.sink { (value) in
            S1LogDebug("Settings: historyLimit -> \(String(describing: value))")
        }.disposed(by: bag)
        forumOrder.sink { (value) in
            S1LogDebug("Settings: forumOrder -> \(String(describing: value))")
        }.disposed(by: bag)
        reverseAction.sink { (value) in
            S1LogDebug("Settings: reverseAction -> \(String(describing: value))")
        }.disposed(by: bag)
        hideStickTopics.sink { (value) in
            S1LogDebug("Settings: hideStickTopics -> \(String(describing: value))")
        }.disposed(by: bag)
        shareWithoutImage.sink { (value) in
            S1LogDebug("Settings: shareWithoutImage -> \(String(describing: value))")
        }.disposed(by: bag)
        tapticFeedbackForForumSwitch.sink { (value) in
            S1LogDebug("Settings: tapticFeedbackForForumSwitch -> \(String(describing: value))")
        }.disposed(by: bag)
        gestureControledNightModeSwitch.sink { (value) in
            S1LogDebug("Settings: gestureControledNightModeSwitch -> \(String(describing: value))")
        }.disposed(by: bag)
        previousWebKitCacheCleaningDate.sink { (value) in
            S1LogDebug("Settings: previousWebKitCacheCleaningDate -> \(String(describing: value))")
        }.disposed(by: bag)
        lastDailyTaskDate.sink { (value) in
            S1LogDebug("Settings: lastDailyTaskDate -> \(String(describing: value))")
        }.disposed(by: bag)
    }
}
