//
//  S1Floor.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import JASON
import CocoaLumberjack

private let kFloorID = "floorID"
private let kIndexMark  = "indexMark"
private let kAuthor = "author"
private let kAuthorID  = "authorID"
private let kPostTime = "postTime"
private let kContent = "content"
private let kPoll = "poll"
private let kMessage = "message"
private let kImageAttachmentURLStringList = "imageAttachmentList"
private let kFirstQuoteReplyFloorID = "firstQuoteReplyFloorID"

class Floor: NSObject, NSCoding {
    let ID: Int
    var indexMark: String?
    var author: User
    var creationDate: NSDate?
    var content: String?
    var message: String?
    var imageAttachmentURLStringList: [String]?

    init?(json: JSON) {
        guard let
            IDString = json["pid"].string, ID = Int(IDString),
            authorIDString = json["authorid"].string, authorID = Int(authorIDString),
            authorName = json["author"].string else {
                return nil
        }

        self.ID = ID
        self.author = User(ID: authorID, name: authorName)

        super.init()
        // FIXME: finish this.
    }

    required init?(coder aDecoder: NSCoder) {

        guard let
            ID = aDecoder.decodeObjectForKey(kFloorID) as? Int,
            authorID = aDecoder.decodeObjectForKey(kAuthorID) as? Int,
            authorName = aDecoder.decodeObjectForKey(kAuthor) as? String else {
                return nil
        }

        self.ID = ID
        self.author = User(ID: authorID, name: authorName)

        super.init()

        self.indexMark = aDecoder.decodeObjectForKey(kIndexMark) as? String

        self.creationDate = aDecoder.decodeObjectForKey(kPostTime) as? NSDate
        self.content = aDecoder.decodeObjectForKey(kContent) as? String
        self.message = aDecoder.decodeObjectForKey(kMessage) as? String
        self.imageAttachmentURLStringList = aDecoder.decodeObjectForKey(kImageAttachmentURLStringList) as? [String]
    }

    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.ID, forKey: kFloorID)
        aCoder.encodeObject(self.indexMark, forKey: kIndexMark)
        aCoder.encodeObject(self.author.name, forKey: kAuthor)
        aCoder.encodeObject(self.author.ID, forKey: kAuthorID)
        aCoder.encodeObject(self.creationDate, forKey: kPostTime)
        aCoder.encodeObject(self.content, forKey: kContent)
        aCoder.encodeObject(self.message, forKey: kMessage)
        aCoder.encodeObject(self.imageAttachmentURLStringList, forKey: kImageAttachmentURLStringList)
    }
}

extension Floor {
    var firstQuoteReplyFloorID: Int? {
        guard let
            content = self.content,
            URLString = S1Global.regexExtractFromString(content, withPattern: "<div class=\"quote\"><blockquote><a href=\"([^\"]*)\"", andColums: [1]).first as? String,
            resultDict = S1Parser.extractQuerysFromURLString(URLString.gtm_stringByUnescapingFromHTML()),
            floorIDString = resultDict["pid"] as? String,
            floorID = Int(floorIDString) else { return nil }

        DDLogDebug("First Quote Floor ID: \(floorID)")

        return floorID
    }
}
