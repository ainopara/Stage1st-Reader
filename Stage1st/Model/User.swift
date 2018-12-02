//
//  S1User.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import SwiftyJSON

private let kUserID = "userID"
private let kUserName = "userName"
private let kCustomStatus = "customStatus"

public final class User: NSObject {
    let ID: Int
    var name: String
    var customStatus: String?

    var threadCount: Int?
    var postCount: Int?
    var fightingCapacity: Int?

    var lastVisitDateString: String?
    var registerDateString: String?

    var sigHTML: String?

    @objc public init(ID: Int, name: String) {
        self.ID = ID
        self.name = name
        super.init()
    }

    public init?(json: JSON) {
        let space = json["Variables"]["space"]

        guard
            let IDString = space["uid"].string,
            let ID = Int(IDString),
            let name = space["username"].string
        else {
            return nil
        }

        self.ID = ID
        self.name = name
        customStatus = space["customstatus"].string

        if
            let sigHTML = space["sightml"].string,
            sigHTML != ""
        {
            self.sigHTML = sigHTML
        }

        lastVisitDateString = space["lastvisit"].string
        registerDateString = space["regdate"].string

        if
            let threadCountString = space["threads"].string,
            let threadCount = Int(threadCountString)
        {
            self.threadCount = threadCount
        }

        if
            let postCountString = space["posts"].string,
            let postCount = Int(postCountString)
        {
            self.postCount = postCount
        }
    }
}

extension User {
    var avatarURL: URL? {
        return URL(string: "https://centeru.saraba1st.com/avatar.php?uid=\(ID)&size=middle")
    }
}
