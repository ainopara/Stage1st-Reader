//
//  S1User.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import JASON

private let kUserID = "userID"
private let kUserName = "userName"
private let kCustomStatus = "customStatus"

open class User: NSObject, NSCoding {
    let ID: Int
    var name: String
    var customStatus: String?
    var sigHTML: String?
    var lastVisitDateString: String?
    var registerDateString: String?
    var threadCount: Int?
    var postCount: Int?

    public init(ID: Int, name: String) {
        self.ID = ID
        self.name = name
        super.init()
    }

    public init?(json: JSON) {
        let space = json["Variables"]["space"]
        guard let IDString = space["uid"].string,
              let ID = Int(IDString),
              let name = space["username"].string else {
            return nil
        }

        self.ID = ID
        self.name = name
        self.customStatus = space["customstatus"].string
        if let sigHTML = space["sightml"].string, sigHTML != "" {
            self.sigHTML = sigHTML
        }
        self.lastVisitDateString = space["lastvisit"].string
        self.registerDateString = space["regdate"].string
        if let threadCountString = space["threads"].string, let threadCount = Int(threadCountString) {
            self.threadCount = threadCount
        }
        if let postCountString = space["posts"].string, let postCount = Int(postCountString) {
            self.postCount = postCount
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        let ID = aDecoder.decodeObject(forKey: kUserID) as? Int ?? aDecoder.decodeInteger(forKey: kUserID)
        guard ID != 0,
              let name = aDecoder.decodeObject(forKey: kUserName) as? String else {
            return nil
        }

        self.ID = ID
        self.name = name
        self.customStatus = aDecoder.decodeObject(forKey: kCustomStatus) as? String
        super.init()
        // FIXME: Finish it.
    }

    open func encode(with aCoder: NSCoder) {
        aCoder.encode(self.ID, forKey: kUserID)
        aCoder.encode(self.name, forKey: kUserName)
        aCoder.encode(self.customStatus, forKey: kCustomStatus)
        // FIXME: Finish it.
    }
}

extension User {
    var avatarURL: URL? {
        return URL(string: "http://bbs.saraba1st.com/2b/uc_server/avatar.php?uid=\(self.ID)")
    }
}
