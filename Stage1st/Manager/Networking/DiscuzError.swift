//
//  DiscuzError.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/12/22.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation

public enum DiscuzError: Error {
    case loginSerializationFailed(code: Int, mime: String, body: String)
    case loginFailed(message: RawMessage)
    case loginFetchSeccodeImageFailed
    case userInfoParseFailed(jsonString: String)
    case noFieldInfoReturned(jsonString: String)
    case noThreadListReturned(jsonString: String)
    case threadParseFailed(jsonString: String)
    case searchResultParseFailed
    case serverError(message: String)
}

extension DiscuzError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .loginSerializationFailed(code, mime, body):
            return "Login response failed to decode to json dictionay with responseCode: \(code), MIME: \(mime), body: \(body)"
        case let .loginFailed(message):
            return "Login failed due to `login_success` can not be founded in messageval `\(message.key)` with messagestr: `\(message.description)`"
        case .loginFetchSeccodeImageFailed:
            return "Failed to fetch seccode image when login."
        case let .userInfoParseFailed(jsonString):
            return "User info failed to parse for json `\(jsonString)`"
        case let .noFieldInfoReturned(jsonString):
            return "No field information in json `\(jsonString)`"
        case let .noThreadListReturned(jsonString):
            return "No thread list in json `\(jsonString)`"
        case let .threadParseFailed(jsonString):
            return "Thread failed to parse for json `\(jsonString)`"
        case .searchResultParseFailed:
            return "Search result parse failed"
        case let .serverError(message):
            return message.description
        }
    }
}

extension DiscuzError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}

extension DiscuzError: CustomNSError {

    public static var errorDomain: String {
        return "DiscuzError"
    }

    public var errorCode: Int {
        switch self {
        case .serverError:
            return 0
        case .loginFailed:
            return 100
        case .loginSerializationFailed:
            return 101
        case .loginFetchSeccodeImageFailed:
            return 102
        case .userInfoParseFailed:
            return 200
        case .noFieldInfoReturned:
            return 300
        case .noThreadListReturned:
            return 400
        case .threadParseFailed:
            return 500
        case .searchResultParseFailed:
            return 600
        }
    }

    public var errorUserInfo: [String: Any] {
        switch self {
        case .serverError(let message):
            return ["message": message]
        case .loginFailed(let message):
            return [
                "key": message.key,
                "description": message.description
            ]
        case .loginSerializationFailed(let code, let mime, let body):
            return [
                "responseCode": code,
                "MIME": mime,
                "body": body
            ]
        case .loginFetchSeccodeImageFailed:
            return [:]
        case .userInfoParseFailed(let jsonString):
            return ["value": jsonString]
        case .noFieldInfoReturned(let jsonString):
            return ["value": jsonString]
        case .noThreadListReturned(let jsonString):
            return ["value": jsonString]
        case .threadParseFailed(let jsonString):
            return ["value": jsonString]
        case .searchResultParseFailed:
            return [:]
        }
    }
}
