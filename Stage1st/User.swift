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

public final class User: NSObject, NSCoding {
    let ID: UInt
    var name: String
    var customStatus: String?
    var sigHTML: String?
    var lastVisitDateString: String?
    var registerDateString: String?
    var threadCount: UInt?
    var postCount: UInt?

    @objc public init(ID: UInt, name: String) {
        self.ID = ID
        self.name = name
        super.init()
    }

    public init?(json: JSON) {
        let space = json["Variables"]["space"]
        guard let IDString = space["uid"].string,
            let ID = UInt(IDString),
            let name = space["username"].string else {
            return nil
        }

        self.ID = ID
        self.name = name
        customStatus = space["customstatus"].string
        if let sigHTML = space["sightml"].string, sigHTML != "" {
            self.sigHTML = sigHTML
        }

        lastVisitDateString = space["lastvisit"].string
        registerDateString = space["regdate"].string

        if let threadCountString = space["threads"].string,
            let threadCount = UInt(threadCountString) {
            self.threadCount = threadCount
        }
        if let postCountString = space["posts"].string,
            let postCount = UInt(postCountString) {
            self.postCount = postCount
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        let ID = aDecoder.decodeObject(forKey: kUserID) as? UInt ?? UInt(aDecoder.decodeInteger(forKey: kUserID))
        guard ID != 0,
            let name = aDecoder.decodeObject(forKey: kUserName) as? String else {
            return nil
        }

        self.ID = ID
        self.name = name
        customStatus = aDecoder.decodeObject(forKey: kCustomStatus) as? String
        super.init()
        // FIXME: Finish it.
    }

    open func encode(with aCoder: NSCoder) {
        aCoder.encode(Int(ID), forKey: kUserID)
        aCoder.encode(name, forKey: kUserName)
        aCoder.encode(customStatus, forKey: kCustomStatus)
        // FIXME: Finish it.
    }
}
