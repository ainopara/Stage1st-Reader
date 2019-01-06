//
//  ReplyNotice.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/21.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import CodableExtensions

public struct ReplyNotice: Codable {
    public let id: Int
    public let uid: Int
    public let type: String
    public let new: Bool
    public let authorid: Int
    public let author: String
    public let note: String
    public let dateline: Date
    public let fromId: Int
    public let fromIdtype: String
    public let fromNum: Int
    private enum CodingKeys: String, CodingKey {
        case id
        case uid
        case type
        case new
        case authorid
        case author
        case note
        case dateline
        case fromId = "from_id"
        case fromIdtype = "from_idtype"
        case fromNum = "from_num"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(.id, transformer: StringIntTransformer())
        self.uid = try container.decode(.uid, transformer: StringIntTransformer())
        self.type = try container.decode(String.self, forKey: .type)
        self.new = try container.decode(.new, transformer: StringBoolTransformer())
        self.authorid = try container.decode(.authorid, transformer: StringIntTransformer())
        self.author = try container.decode(String.self, forKey: .author)
        self.note = try container.decode(String.self, forKey: .note)
        self.dateline = try container.decode(.dateline, transformer: StringDateTransformer(dateType: .secondSince1970))
        self.fromId = try container.decode(.fromId, transformer: StringIntTransformer())
        self.fromIdtype = try container.decode(String.self, forKey: .fromIdtype)
        self.fromNum = try container.decode(.fromNum, transformer: StringIntTransformer())
    }
}
