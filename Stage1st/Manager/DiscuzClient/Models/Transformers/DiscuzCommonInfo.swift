//
//  DiscuzCommonInfo.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/21.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation

public struct DiscuzCommonInfo: Codable {
    public let auth: String?
    public let saltkey: String
    public let memberUid: String
    public let memberUsername: String
    public let memberAvatar: URL
    public let groupid: String
    public let formhash: String
    public let readaccess: String
    public let notice: NoticeCount
    public let count: String?
    public let perpage: String?
    public let page: String
    private enum CodingKeys: String, CodingKey {
        case auth
        case saltkey
        case memberUid = "member_uid"
        case memberUsername = "member_username"
        case memberAvatar = "member_avatar"
        case groupid
        case formhash
        case readaccess
        case notice
        case count
        case perpage
        case page
    }
}
