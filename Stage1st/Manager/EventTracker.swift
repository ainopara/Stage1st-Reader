//
//  EventTracker.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/3.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Crashlytics
import Sentry

protocol EventTracker {
    func recordAssertionFailure(_ error: Error)
    func recordError(_ error: Error)
    func recordError(_ error: Error, withAdditionalUserInfo userInfo: [String: Any]?)

    func logEvent(_ name: String)
    func logEvent(_ name: String, attributes: [String: String]?)
    func logEvent(_ name: String, uploadImmediately: Bool)
    func logEvent(_ name: String, attributes: [String: String]?, uploadImmediately: Bool)

    func setObjectValue(_ value: String, forKey key: String)
}

class S1EventTracker: EventTracker {

    private(set) var extraInfo: [String: String] = [:]

    func recordAssertionFailure(_ error: Error) {
        recordError(error, withAdditionalUserInfo: nil, level: .error)
    }

    func recordError(_ error: Error) {
        recordError(error, withAdditionalUserInfo: nil, level: .warning)
    }

    func recordError(_ error: Error, withAdditionalUserInfo userInfo: [String: Any]?) {
        recordError(error, withAdditionalUserInfo: userInfo, level: .warning)
    }

    func recordError(_ error: Error, withAdditionalUserInfo userInfo: [String: Any]?, level: SentryLevel) {
        Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: userInfo)

        let extraInfoSnapshot = self.extraInfo

        let event = Event(level: .warning)
        let nsError = error as NSError
        let message = "\(nsError.domain):\(nsError.code)"
        event.message = SentryMessage(formatted: message)
        event.extra = nsError.userInfo
            .merging(userInfo ?? [:], uniquingKeysWith: { $1 })
            .merging(extraInfoSnapshot, uniquingKeysWith: { $1 })
        event.fingerprint = [message]
        SentrySDK.capture(event: event)
    }

    func logEvent(_ name: String) {
        self.logEvent(name, attributes: nil, uploadImmediately: false)
    }

    func logEvent(_ name: String, attributes: [String: String]?) {
        self.logEvent(name, attributes: attributes, uploadImmediately: false)
    }

    func logEvent(_ name: String, uploadImmediately: Bool) {
        self.logEvent(name, attributes: nil, uploadImmediately: uploadImmediately)
    }

    func logEvent(_ name: String, attributes: [String: String]?, uploadImmediately: Bool) {
        Answers.logCustomEvent(withName: name, customAttributes: attributes)

        let event = Event(level: .info)
        event.message = SentryMessage(formatted: name)
        event.tags = attributes
        // Assigning an empty breadcrumbs will prevent client from attching stored breadcrumbs to this event
        event.breadcrumbs = []
        // Assigning threads and debugMeta will prevent client from generating threads and debugMeta for this event
        event.threads = [Sentry.Thread(threadId: 0)]
        event.debugMeta = [DebugMeta()]
        SentrySDK.capture(event: event)
    }

    func setObjectValue(_ value: String, forKey key: String) {
        extraInfo[key] = value
        Crashlytics.sharedInstance().setObjectValue(value, forKey: key)
    }
}
