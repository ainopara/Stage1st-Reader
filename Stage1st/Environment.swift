//
//  Environment.swift
//  Stage1st
//
//  Created by Zheng Li on 13/03/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation

struct Environment {
    let forumName: String
    let baseURL: String
    let apiService: DiscuzClient
    let cookieStorage: HTTPCookieStorage
    let serverAddress: ServerAddress

    init(forumName: String = "Stage1st",
         serverAddress: ServerAddress = ServerAddress.traced,
         cookieStorage: HTTPCookieStorage = HTTPCookieStorage.shared) {
        self.forumName = forumName
        self.serverAddress = serverAddress
        baseURL = serverAddress.main
        apiService = DiscuzClient(baseURL: baseURL)
        self.cookieStorage = cookieStorage
    }
}
