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
    func recordError(_ error: Error)
    func recordError(_ error: Error, withAdditionalUserInfo userInfo: [String: Any]?)

    func logEvent(with name: String)
    func logEvent(with name: String, attributes: [String: Any]?)

    func setObjectValue(_ value: String, forKey key: String)
}

class S1EventTracker: EventTracker {

    private(set) var extraInfo: [String: String] = [:]

    func recordError(_ error: Error) {
        recordError(error, withAdditionalUserInfo: nil)
    }

    func recordError(_ error: Error, withAdditionalUserInfo userInfo: [String: Any]?) {
        Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: userInfo)

        let extraInfoSnapshot = self.extraInfo

        Client.shared?.snapshotStacktrace {
            let event = Event(level: .error)
            let nsError = error as NSError
            event.message = "\(nsError.domain):\(nsError.code)"
            event.extra = nsError.userInfo
                .merging(userInfo ?? [:], uniquingKeysWith: { $1 })
                .merging(extraInfoSnapshot, uniquingKeysWith: { $1 })
            Client.shared?.appendStacktrace(to: event)
            Client.shared?.send(event: event)
        }
    }

    func logEvent(with name: String) {
        self.logEvent(with: name, attributes: nil)
    }

    func logEvent(with name: String, attributes: [String: Any]?) {
        Answers.logCustomEvent(withName: name, customAttributes: attributes)
    }

    func setObjectValue(_ value: String, forKey key: String) {
        extraInfo[key] = value
        Crashlytics.sharedInstance().setObjectValue(value, forKey: key)
    }
}
