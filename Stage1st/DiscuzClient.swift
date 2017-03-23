//
//  DiscuzClient.swift
//  Stage1st
//
//  Created by Zheng Li on 5/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import SwiftyJSON

public extension Notification.Name {
    public static let DZLoginStatusDidChangeNotification = Notification.Name.init(rawValue: "DZLoginStatusDidChangeNotification")
}

public enum DZError: Error {
    case loginFailed(messageValue: String, messageString: String)
    case userInfoParseFailed(jsonString: String)
    case noFieldInfoReturned(jsonString: String)
    case noThreadListReturned(jsonString: String)
    case threadParseFailed(jsonString: String)
}

extension DZError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .loginFailed(messageValue, messageString):
            return "Login failed due to `login_success` can not be founded in messageval `\(messageValue)` with messagestr: `\(messageString)`"
        case let .userInfoParseFailed(jsonString):
            return "User info failed to parse for json `\(jsonString)`"
        case let .noFieldInfoReturned(jsonString):
            return "No field information in json `\(jsonString)`"
        case let .noThreadListReturned(jsonString):
            return "No thread list in json `\(jsonString)`"
        case let .threadParseFailed(jsonString):
            return "Thread failed to parse for json `\(jsonString)`"
        }
    }
}

extension DZError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}

public final class DiscuzClient: NSObject {
    let baseURL: String
    var formhash: String?
    var auth: String?

    init(baseURL: String) {
        self.baseURL = baseURL
        super.init()
    }
}
