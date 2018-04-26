//
//  Settings.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/4/17.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import ReactiveSwift
import ReactiveCocoa
import QuickTableViewController
import CrashlyticsLogger
import DeviceKit
import AlamofireImage

/// Extend this class and add your user defaults keys as static constants
/// so you can use the shortcut dot notation (e.g. `Defaults[.yourKey]`)
public class DefaultsKeys {
    fileprivate init() {}
}

/// Base class for static user defaults keys. Specialize with value type
/// and pass key name to the initializer to create a key.
public class DefaultsKey<ValueType: DefaultsCompatible>: DefaultsKeys {
    public let keyString: String

    public init(_ key: String) {
        self.keyString = key
        super.init()
    }
}

public protocol DefaultsCompatible {}
extension String: DefaultsCompatible {}
extension Int: DefaultsCompatible {}
extension Double: DefaultsCompatible {}
extension Bool: DefaultsCompatible {}
extension Array: DefaultsCompatible where Element: DefaultsCompatible {}
extension Dictionary: DefaultsCompatible where Key == String, Value: DefaultsCompatible {}
extension Data: DefaultsCompatible {}
extension Date: DefaultsCompatible {}
extension URL: DefaultsCompatible {}

extension UserDefaults {
    public subscript<T: DefaultsCompatible>(key: DefaultsKey<T>) -> T? {
        get { return self[key.keyString].flatMap({ $0 as? T }) }
        set { self[key.keyString] = newValue }
    }

    private subscript(key: String) -> Any? {
        get { return object(forKey: key) }
        set {
            guard let newValue = newValue else {
                removeObject(forKey: key)
                return
            }

            switch newValue {
            // This should always be on top of Int because a cast
            // from Double to Int will always succeed.
            case let value as Double:
                self.set(value, forKey: key)
            case let value as Int:
                self.set(value, forKey: key)
            case let value as Bool:
                self.set(value, forKey: key)
            case let value as URL:
                self.set(value, forKey: key)
            default:
                self.set(newValue, forKey: key)
            }
        }
    }
}

extension MutableProperty where Value: Equatable {
    func setValueIfDifferent(_ newValue: Value) {
        if self.value != newValue { self.value = newValue }
    }
}

// MARK: -

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

class Settings: NSObject {
    let defaults: UserDefaults
    private var observingKeyPaths: [String: ((Any) -> Void)] = [:]
    private var disposables: [Disposable?] = []

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

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
        super.init()

        // Login
        bind(propertyKeyPath: \.currentUsername, to: .currentUsername)

        // Settings
        bind(propertyKeyPath: \.displayImage, to: .displayImage, defaultValue: true)
        bind(propertyKeyPath: \.removeTails, to: .removeTails, defaultValue: true)
        bind(propertyKeyPath: \.precacheNextPage, to: .precacheNextPage, defaultValue: true)
        bind(propertyKeyPath: \.forcePortraitForPhone, to: .forcePortraitForPhone, defaultValue: true)
        bind(propertyKeyPath: \.nightMode, to: .nightMode, defaultValue: false)
        bind(propertyKeyPath: \.enableCloudKitSync, to: .enableCloudKitSync, defaultValue: false)
        bind(propertyKeyPath: \.historyLimit, to: .historyLimit, defaultValue: -1)
        bind(propertyKeyPath: \.forumOrder, to: .forumOrder, defaultValue: [[], []])

        // Advanced Settings
        bind(propertyKeyPath: \.reverseAction, to: .reverseAction, defaultValue: false)
        bind(propertyKeyPath: \.hideStickTopics, to: .hideStickTopics, defaultValue: true)

        // Cleaning
        bind(propertyKeyPath: \.previousWebKitCacheCleaningDate, to: .previousWebKitCacheCleaningDate)

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

    deinit {
        for (key, _) in observingKeyPaths {
            defaults.removeObserver(self, forKeyPath: key)
        }

        for disposalbe in disposables {
            disposalbe?.dispose()
        }
    }

    func bind<T>(
        propertyKeyPath: KeyPath<Settings, MutableProperty<T>>,
        to key: DefaultsKey<T>,
        defaultValue: T
    ) where
        T: DefaultsCompatible,
        T: Equatable
    {
        let property = self[keyPath: propertyKeyPath]

        // Initial value set from UserDefaults
        property.value = defaults[key] ?? defaultValue

        // Binding changes in property -> UserDefaults
        let disposable = property.skipRepeats().signal.observeValues { [weak self] (value) in
            guard let strongSelf = self else { return }
            guard strongSelf.defaults[key] != value else { return }
            strongSelf.defaults[key] = value
        }
        disposables.append(disposable)

        // Binding changes in UserDefaults -> property
        let keyPath = "\(key.keyString)"
        S1LogDebug("Register KVO keypath: \(keyPath)")
        defaults.addObserver(self, forKeyPath: keyPath, options: [.new], context: nil)
        observingKeyPaths[keyPath] = { (newValue) in
            if newValue is NSNull {
                property.setValueIfDifferent(defaultValue)
            } else if let newValue = newValue as? T {
                property.setValueIfDifferent(newValue)
            } else {
                S1LogError("Expect newValue \(newValue) has Type \(T.self) or NSNull but got \(type(of: newValue))")
                property.setValueIfDifferent(defaultValue)
            }
        }
    }

    func bind<T>(
        propertyKeyPath: KeyPath<Settings, MutableProperty<T?>>,
        to key: DefaultsKey<T>
    ) where
        T: DefaultsCompatible,
        T: Equatable
    {
        let property = self[keyPath: propertyKeyPath]

        // Initial value set from UserDefaults
        property.value = defaults[key]

        // Binding changes in property -> UserDefaults
        let disposable = property.skipRepeats().signal.observeValues { [weak self] (value) in
            guard let strongSelf = self else { return }
            guard strongSelf.defaults[key] != value else { return }
            strongSelf.defaults[key] = value
        }
        disposables.append(disposable)

        // Binding changes in UserDefaults -> property
        let keyPath = "\(key.keyString)"
        S1LogDebug("Register KVO keypath: \(keyPath)")
        defaults.addObserver(self, forKeyPath: keyPath, options: [.new], context: nil)
        observingKeyPaths[keyPath] = { (newValue) in
            if newValue is NSNull {
                property.setValueIfDifferent(.none)
            } else if let newValue = newValue as? T {
                property.setValueIfDifferent(.some(newValue))
            } else {
                S1LogError("Expect newValue \(newValue) has Type \(T.self) or NSNull but got \(type(of: newValue))")
                property.setValueIfDifferent(.none)
            }
        }
    }

    // swiftlint:disable block_based_kvo
    @objc override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else {
            fatalError("keyPath should not be nil.")
        }

        guard let newValue = change?[.newKey] else {
            fatalError("changes[.newKey] should not be nil.")
        }

        guard let callback = observingKeyPaths[keyPath] else {
            fatalError("observingKeyPaths should have information about \(keyPath)")
        }

        callback(newValue)
    }
}
