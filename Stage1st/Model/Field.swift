//
//  Field.swift
//  Stage1st
//
//  Created by Zheng Li on 09/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation
import CodableExtensions

public struct RawForum: Decodable {
    public let id: String
    public let name: String
    public let threadCount: String
    public let postCount: String
    public let rules: String?

    private enum CodingKeys: String, CodingKey {
        case id = "fid"
        case name
        case threadCount = "threads"
        case postCount = "posts"
        case rules
    }
}

public struct Field: Codable {
    public let id: Int
    public let name: String
    public let threadCount: Int
    public let postCount: Int
    public let rules: String?
}

extension Field {
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
