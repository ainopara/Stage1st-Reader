//
//  DiscuzClient.swift
//  Stage1st
//
//  Created by Zheng Li on 5/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Alamofire

public final class DiscuzClient: NSObject {
    public let baseURL: String

    public init(baseURL: String) {
        self.baseURL = baseURL
        super.init()
    }
}

extension DiscuzClient {
    static let loginStatusDidChangeNotification = Notification.Name.init(rawValue: "DiscuzLoginStatusDidChangeNotification")
}

struct FailureURL: URLConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    func asURL() throws -> URL {
        throw message
    }
}
