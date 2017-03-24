//
//  Environment.swift
//  Stage1st
//
//  Created by Zheng Li on 13/03/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation

struct Environment {
    let baseURL: String
    let apiService: DiscuzClient
    let cookieStorage: HTTPCookieStorage

    init(baseURL: String = "http://bbs.stage1.cc",
         apiService: DiscuzClient = DiscuzClient(baseURL: "http://bbs.stage1.cc"),
         cookieStorage: HTTPCookieStorage = HTTPCookieStorage.shared) {
        self.baseURL = baseURL
        self.apiService = apiService
        self.cookieStorage = cookieStorage
    }
}
