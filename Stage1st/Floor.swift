//
//  S1Floor.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

class Floor: NSObject, NSCoding {
    let ID: Int
    var indexMark: String?
    var author: User?
    var creationDate: NSDate?
    var content: String?
    var message: String?
    var imageAttachmentList: [String]?

    var firstQuoteReplyFloorID: Int? {
        return nil
    }

    required init?(coder aDecoder: NSCoder) {

        guard let ID = aDecoder.decodeObjectForKey("floorID") as? Int else {
            return nil
        }
        self.ID = ID

        super.init()

        self.indexMark = aDecoder.decodeObjectForKey("indexMark") as? String
        self.author = aDecoder.decodeObjectForKey("") as? User
        self.creationDate = aDecoder.decodeObjectForKey("postTime") as? NSDate
        self.content = aDecoder.decodeObjectForKey("content") as? String
        self.message = aDecoder.decodeObjectForKey("message") as? String
        self.imageAttachmentList = aDecoder.decodeObjectForKey("imageAttachmentList") as? [String]
    }

    func encodeWithCoder(aCoder: NSCoder) {

    }
}
