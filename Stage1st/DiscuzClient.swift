//
//  DiscuzClient.swift
//  Stage1st
//
//  Created by Zheng Li on 5/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

public final class DiscuzClient: NSObject {
    let baseURL: String
    var formhash: String?
    var auth: String?

    init(baseURL: String) {
        self.baseURL = baseURL
        super.init()
    }
}
