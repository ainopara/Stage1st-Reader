//
//  NetworkModels.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/20.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation
import CodableExtensions

struct RawTopicList: Codable {
    struct Variables: Codable {
        let cookiepre: String
        let auth: String
        let saltkey: String
        let memberUid: String
        let memberUsername: String
        let memberAvatar: URL
        let groupid: String
        let formhash: String
        let readaccess: String
        let notice: NoticeCount
        struct Topic: Codable {
            let tid: String
            let fid: String
            let posttableid: String
            let typeid: String
            let sortid: String
            let readperm: String
            let price: String
            let author: String
            let authorid: String
            let subject: String
            let dateline: String
            let lastpost: String
            let lastposter: String
            let views: String
            let replies: String
            let displayorder: String
            let highlight: String
            let digest: String
            let rate: String
            let special: String
            let attachment: String
            let moderated: String
            let closed: String
            let stickreply: String
            let recommends: String
            let recommendAdd: String
            let recommendSub: String
            let heats: String
            let status: String
            let isgroup: String
            let favtimes: String
            let sharetimes: String
            let stamp: String
            let icon: String
            let pushedaid: String
            let cover: String
            let replycredit: String
            let relatebytag: String
            let maxposition: String
            let bgcolor: String
            let comments: String
            let hidden: String
            let lastposterenc: String
            let multipage: String
            let pages: String?
            let recommendicon: String
            let new: String
            let heatlevel: String
            let moved: String
            let icontid: String
            let folder: String
            let weeknew: String
            let istoday: String
            let dbdateline: String
            let dblastpost: String
            let id: String
            let rushreply: String
            private enum CodingKeys: String, CodingKey {
                case tid
                case fid
                case posttableid
                case typeid
                case sortid
                case readperm
                case price
                case author
                case authorid
                case subject
                case dateline
                case lastpost
                case lastposter
                case views
                case replies
                case displayorder
                case highlight
                case digest
                case rate
                case special
                case attachment
                case moderated
                case closed
                case stickreply
                case recommends
                case recommendAdd = "recommend_add"
                case recommendSub = "recommend_sub"
                case heats
                case status
                case isgroup
                case favtimes
                case sharetimes
                case stamp
                case icon
                case pushedaid
                case cover
                case replycredit
                case relatebytag
                case maxposition
                case bgcolor
                case comments
                case hidden
                case lastposterenc
                case multipage
                case pages
                case recommendicon
                case new
                case heatlevel
                case moved
                case icontid
                case folder
                case weeknew
                case istoday
                case dbdateline
                case dblastpost
                case id
                case rushreply
            }
        }
        let data: [Topic]
        let perpage: String
        private enum CodingKeys: String, CodingKey {
            case cookiepre
            case auth
            case saltkey
            case memberUid = "member_uid"
            case memberUsername = "member_username"
            case memberAvatar = "member_avatar"
            case groupid
            case formhash
            case readaccess
            case notice
            case data
            case perpage
        }
    }
    let variables: Variables
    private enum CodingKeys: String, CodingKey {
        case variables = "Variables"
    }
}
