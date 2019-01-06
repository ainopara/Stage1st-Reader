//
//  NetworkModels.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/20.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation

public struct RawTopicList: Decodable {
    public struct Variables: Decodable {
        public let memberUid: String?
        public let memberUsername: String?
        public let memberAvatar: URL?
        public let formhash: String?
        public let notice: NoticeCount
        public let forum: RawForum
        public struct Thread: Decodable {
            public let tid: String
            public let readperm: String
            public let author: String
            public let authorid: String
            public let subject: String
            public let lastposter: String
            public let views: String
            public let replies: String
            public let dbdateline: String
            public let dblastpost: String
        }
        public let threadList: [Thread]
        private enum CodingKeys: String, CodingKey {
            case memberUid = "member_uid"
            case memberUsername = "member_username"
            case memberAvatar = "member_avatar"
            case formhash
            case notice
            case forum
            case threadList = "forum_threadlist"
        }
    }
    public let variables: Variables?
    public let message: RawMessage?
    public let error: String?

    private enum CodingKeys: String, CodingKey {
        case variables = "Variables"
        case message = "Message"
        case error
    }
}
