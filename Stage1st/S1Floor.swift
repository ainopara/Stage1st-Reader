//
//  S1Floor.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

class Floor: NSObject, NSCoding {
    var ID: Int?
    var indexMark: String?
    var author: User?
    var creationDate: NSDate?
    var content: String?
    var message: String?
    var imageAttachmentList: [String]?

    var firstQuoteReplyFloorID: Int? {
        return 0
    }

    required init?(coder aDecoder: NSCoder) {
        self.ID = aDecoder.decodeObjectForKey("") as? Int
        self.indexMark = aDecoder.decodeObjectForKey("") as? String
        self.author = aDecoder.decodeObjectForKey("") as? User
        self.creationDate = aDecoder.decodeObjectForKey("") as? NSDate
        self.content = aDecoder.decodeObjectForKey("") as? String
        self.message = aDecoder.decodeObjectForKey("") as? String
        self.imageAttachmentList = aDecoder.decodeObjectForKey("") as? [String]

        super.init()
    }

    func encodeWithCoder(aCoder: NSCoder) {

    }
}
