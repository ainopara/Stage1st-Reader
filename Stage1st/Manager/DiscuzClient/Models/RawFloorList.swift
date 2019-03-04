//
//  RawFloorList.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation

public struct RawFloorList: Decodable {
    public struct Variables: Decodable {
        public let memberUid: String?
        public let memberUsername: String?
        public let memberAvatar: URL?
        public let formhash: String?
        public let notice: NoticeCount
        public struct Thread: Decodable {
            public let tid: String
            public let fid: String
            public let subject: String
            public let authorid: String
            public let views: String
            public let author: String
            public let lastpost: String
            public let replies: String

            private enum CodingKeys: String, CodingKey {
                case tid
                case fid
                case subject
                case authorid
                case views
                case author
                case lastpost
                case replies
            }
        }
        public let thread: Thread
        public struct Post: Decodable {
            public let pid: String
            public let tid: String
            public let first: String
            public let author: String
            public let authorid: String
            public let dateline: String
            public let message: String?
            public let anonymous: String
            public let attachment: String
            public let status: String
            public let username: String?
            public let adminid: String?
            public let groupid: String
            public let memberstatus: String?
            public let number: String
            public let dbdateline: String
            public struct Attachment: Decodable {
                public let aid: String
                public let tid: String?
                public let pid: String?
                public let uid: String?
                public let dateline: String?
                public let filename: String?
                public let filesize: String?
                public let attachment: String
                public let remote: String?
                public let description: String?
                public let readperm: String?
                public let price: String?
                public let isimage: String?
                public let width: String?
                public let thumb: String?
                public let picid: String?
                public let ext: String?
                public let imgalt: String?
                public let attachicon: String?
                public let attachsize: String?
                public let attachimg: String?
                public let payed: String?
                public let url: URL
                public let dbdateline: String?
                public let downloads: String?
            }
            public let attachments: [String: Attachment]?
            public let imageList: [String]?
        }
        public let postList: [Post]

        private enum CodingKeys: String, CodingKey {
            case memberUid = "member_uid"
            case memberUsername = "member_username"
            case memberAvatar = "member_avatar"
            case formhash
            case notice
            case thread
            case postList = "postlist"
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
