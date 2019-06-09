//
//  EventTracker.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/3.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Crashlytics

protocol EventTracker {
    func recordError(_ error: Error)
    func recordError(_ error: Error, withAdditionalUserInfo userInfo: [String: Any])

    func logEvent(with name: String)
    func logEvent(with name: String, attributes: [String: Any])

    func setObjectValue(_ value: String, forKey key: String)
}

class S1EventTracker: EventTracker {

    func recordError(_ error: Error) {
        Crashlytics.sharedInstance().recordError(error)
    }

    func recordError(_ error: Error, withAdditionalUserInfo userInfo: [String: Any]) {
        Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: userInfo)
    }

    func logEvent(with name: String) {
        Answers.logCustomEvent(withName: name, customAttributes: nil)
    }

    func logEvent(with name: String, attributes: [String: Any]) {
        Answers.logCustomEvent(withName: name, customAttributes: attributes)
    }

    func setObjectValue(_ value: String, forKey key: String) {
        Crashlytics.sharedInstance().setObjectValue(value, forKey: key)
    }
}
