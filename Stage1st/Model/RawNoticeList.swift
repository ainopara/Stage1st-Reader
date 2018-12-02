//
//  RawNoticeList.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/21.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation

public struct RawNoticeList: Codable {
    public let info: DiscuzCommonInfo
    public let list: [ReplyNotice]
    public let message: RawMessage?

    private enum FirstLevelCodingKeys: String, CodingKey {
        case info = "Variables"
        case message = "Message"
    }

    private enum SecondLevelCodingKeys: String, CodingKey {
        case list
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FirstLevelCodingKeys.self)
        self.info = try container.decode(DiscuzCommonInfo.self, forKey: .info)
        self.message = try container.decodeIfPresent(RawMessage.self, forKey: .message)

        let variablesContainer = try container.nestedContainer(keyedBy: SecondLevelCodingKeys.self, forKey: .info)
        if  (try? variablesContainer.decode([String].self, forKey: .list)) != nil {
            self.list = []
        } else {
            self.list = try variablesContainer.decode([String: ReplyNotice].self, forKey: .list).values.map { $0 }
        }
    }
}
