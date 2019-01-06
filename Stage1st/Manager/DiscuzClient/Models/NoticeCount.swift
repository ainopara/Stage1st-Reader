//
//  NoticeCount.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/21.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation

public struct NoticeCount: Codable {
    public let push: Int
    public let pm: Int
    public let prompt: Int
    public let myPost: Int

    private enum CodingKeys: String, CodingKey {
        case push = "newpush"
        case pm = "newpm"
        case prompt = "newprompt"
        case myPost = "newmypost"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let transformer = StringIntTransformer()

        self.push = try container.decode(.push, transformer: transformer)
        self.pm = try container.decode(.pm, transformer: transformer)
        self.prompt = try container.decode(.prompt, transformer: transformer)
        self.myPost = try container.decode(.myPost, transformer: transformer)
    }
}
