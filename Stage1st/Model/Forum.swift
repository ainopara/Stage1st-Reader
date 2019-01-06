//
//  Forum.swift
//  Stage1st
//
//  Created by Zheng Li on 09/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation

public struct Forum: Codable {
    public let id: Int
    public let name: String
    public let threadCount: Int
    public let postCount: Int
    public let rules: String?
}

extension Forum {
    init?(rawForum: RawForum) {
        guard
            let id = Int(rawForum.id),
            let threadCount = Int(rawForum.threadCount),
            let postCount = Int(rawForum.postCount)
        else {
            return nil
        }

        self.id = id
        self.name = rawForum.name
        self.threadCount = threadCount
        self.postCount = postCount
        self.rules = rawForum.rules
    }
}
