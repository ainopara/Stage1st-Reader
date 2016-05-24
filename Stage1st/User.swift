//
//  S1User.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import JASON

class User {
    let ID: Int
    var name: String?
    var customStatus: String?
    var sigHTML: String?
    var lastVisitDateString: String?
    var registerDateString: String?
    var threadCount: Int?
    var postCount: Int?

    var avatarURL: NSURL? {
        return NSURL(string: "http://bbs.saraba1st.com/2b/uc_server/avatar.php?uid=\(self.ID)")
    }

    init(ID: Int) {
        self.ID = ID
    }

    init?(json: JSON) {
        let space = json["Variables"]["space"]
        guard let IDString = space["uid"].string, ID = Int(IDString) else { return nil }

        self.ID = ID
        self.name = space["username"].string
        self.customStatus = space["customstatus"].string
        if let sigHTML = space["sightml"].string where sigHTML != "" {
            self.sigHTML = sigHTML
        }
        self.lastVisitDateString = space["lastvisit"].string
        self.registerDateString = space["regdate"].string
        if let threadCountString = space["threads"].string, threadCount = Int(threadCountString) {
            self.threadCount = threadCount
        }
        if let postCountString = space["posts"].string, postCount = Int(postCountString) {
            self.postCount = postCount
        }
    }
}
