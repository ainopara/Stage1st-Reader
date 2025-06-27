//
//  NoticeList.swift
//  Stage1st
//
//  Created by Claude on 2025/6/27.
//  Copyright © 2025 Renaissance. All rights reserved.
//

import Foundation
import CodableExtensions

public struct NoticeList: Codable {
    public let list: [Notice]

    public init(list: [Notice]) {
        self.list = list
    }

    public init(from rawNoticeList: RawNoticeList) {
        self.list = rawNoticeList.list.map { Notice(from: $0) }
    }

    private enum FirstLevelCodingKeys: String, CodingKey {
        case info = "Variables"
    }

    private enum SecondLevelCodingKeys: String, CodingKey {
        case list
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FirstLevelCodingKeys.self)
        let variablesContainer = try container.nestedContainer(keyedBy: SecondLevelCodingKeys.self, forKey: .info)
        
        if (try? variablesContainer.decode([String].self, forKey: .list)) != nil {
            self.list = []
        } else {
            self.list = try variablesContainer.decode([String: Notice].self, forKey: .list).values.map { $0 }
        }
    }
}

public struct Notice: Codable {
    public let type: Kind
    public let new: Bool
    public let authorid: Int
    public let author: String?
    public let note: String
    public let dateline: Date
    
    public enum Kind {
        case post
        case at
        case unknown(String)
    }
    
    public init(from replyNotice: ReplyNotice) {
        self.type = Kind(from: replyNotice.type)
        self.new = replyNotice.new
        self.authorid = replyNotice.authorid
        self.author = replyNotice.author
        self.note = replyNotice.note
        self.dateline = replyNotice.dateline
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case new
        case authorid
        case author
        case note
        case dateline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(Kind.self, forKey: .type)
        self.new = try container.decode(.new, transformer: StringBoolTransformer())
        self.authorid = try container.decode(.authorid, transformer: StringIntTransformer())
        self.author = try container.decodeIfPresent(String.self, forKey: .author)
        self.note = try container.decode(String.self, forKey: .note)
        self.dateline = try container.decode(.dateline, transformer: StringDateTransformer(dateType: .secondSince1970))
    }
}

extension Notice.Kind {
    public init(from replyNoticeKind: ReplyNotice.Kind) {
        switch replyNoticeKind {
        case .post:
            self = .post
        case .at:
            self = .at
        case .unknown(let value):
            self = .unknown(value)
        }
    }
}

extension Notice.Kind: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        switch stringValue {
        case "post":
            self = .post
        case "at":
            self = .at
        default:
            self = .unknown(stringValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    public var rawValue: String {
        switch self {
        case .post:
            return "post"
        case .at:
            return "at"
        case .unknown(let rawValue):
            return rawValue
        }
    }
}