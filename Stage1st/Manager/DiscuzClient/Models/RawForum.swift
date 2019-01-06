//
//  RawForum.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation

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
