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

    func logEvent(with name: String)
    func logEvent(with name: String, attributes: [String: String]?)

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

    func recordError(_ error: Error, withAdditionalUserInfo userInfo: [String: Any]?, level: SentrySeverity) {
        Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: userInfo)

        let extraInfoSnapshot = self.extraInfo

        Client.shared?.snapshotStacktrace {
            let event = Event(level: .warning)
            let nsError = error as NSError
            event.message = "\(nsError.domain):\(nsError.code)"
            event.extra = nsError.userInfo
                .merging(userInfo ?? [:], uniquingKeysWith: { $1 })
                .merging(extraInfoSnapshot, uniquingKeysWith: { $1 })
            /// Make sure different message with same stack trace will be grouped into two issues
            event.fingerprint = ["{{ default }}", event.message]
            Client.shared?.appendStacktrace(to: event)
            Client.shared?.send(event: event)
        }
    }

    func logEvent(with name: String) {
        self.logEvent(with: name, attributes: nil)
    }

    func logEvent(with name: String, attributes: [String: String]?) {
        Answers.logCustomEvent(withName: name, customAttributes: attributes)

        let event = Event(level: .info)
        event.message = name
        event.tags = attributes
        /// Assigning an empty breadcrumbsSerialized will prevent client from attching stored breadcrumbs to this event
        event.breadcrumbsSerialized = [:]
        Client.shared?.store(event)
    }

    func setObjectValue(_ value: String, forKey key: String) {
        extraInfo[key] = value
        Crashlytics.sharedInstance().setObjectValue(value, forKey: key)
    }
}
