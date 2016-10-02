//
//  Floor.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import JASON
import CocoaLumberjack

fileprivate let kFloorID = "floorID"
fileprivate let kIndexMark  = "indexMark"
fileprivate let kAuthor = "author"
fileprivate let kAuthorID  = "authorID"
fileprivate let kPostTime = "postTime"
fileprivate let kContent = "content"
fileprivate let kPoll = "poll"
fileprivate let kMessage = "message"
fileprivate let kImageAttachmentURLStringList = "imageAttachmentList"
fileprivate let kFirstQuoteReplyFloorID = "firstQuoteReplyFloorID"

class Floor: NSObject, NSCoding {
    let ID: Int
    var indexMark: String?
    var author: User
    var creationDate: Date?
    var content: String?
    var message: String?
    var imageAttachmentURLStringList: [String]?

    init(ID: Int, author: User) {
        self.ID = ID
        self.author = author
    }

    init?(json: JSON) {
        guard
            let IDString = json["pid"].string,
            let ID = Int(IDString),
            let authorIDString = json["authorid"].string,
            let authorID = Int(authorIDString),
            let authorName = json["author"].string else {
                return nil
        }

        self.ID = ID
        self.author = User(ID: authorID, name: authorName)

        super.init()
        // FIXME: finish this.
    }

    required init?(coder aDecoder: NSCoder) {
        let ID = aDecoder.decodeObject(forKey: kFloorID) as? Int ?? aDecoder.decodeInteger(forKey: kFloorID)
        let authorID = aDecoder.decodeObject(forKey: kAuthorID) as? Int ?? aDecoder.decodeInteger(forKey: kAuthorID)
        guard
            ID != 0,
            authorID != 0,
            let authorName = aDecoder.decodeObject(forKey: kAuthor) as? String else {
                return nil
        }

        self.ID = ID
        self.author = User(ID: authorID, name: authorName)

        super.init()

        self.indexMark = aDecoder.decodeObject(forKey: kIndexMark) as? String

        self.creationDate = aDecoder.decodeObject(forKey: kPostTime) as? Date
        self.content = aDecoder.decodeObject(forKey: kContent) as? String
        self.message = aDecoder.decodeObject(forKey: kMessage) as? String
        self.imageAttachmentURLStringList = aDecoder.decodeObject(forKey: kImageAttachmentURLStringList) as? [String]
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.ID, forKey: kFloorID)
        aCoder.encode(self.indexMark, forKey: kIndexMark)
        aCoder.encode(self.author.name, forKey: kAuthor)
        aCoder.encode(self.author.ID, forKey: kAuthorID)
        aCoder.encode(self.creationDate, forKey: kPostTime)
        aCoder.encode(self.content, forKey: kContent)
        aCoder.encode(self.message, forKey: kMessage)
        aCoder.encode(self.imageAttachmentURLStringList, forKey: kImageAttachmentURLStringList)
    }
}

extension Floor {
    var firstQuoteReplyFloorID: Int? {
        guard
            let content = self.content,
            let URLString = S1Global.regexExtract(from: content, withPattern: "<div class=\"quote\"><blockquote><a href=\"([^\"]*)\"", andColums: [1]).first as? String,
            let resultDict = S1Parser.extractQuerys(fromURLString: URLString.gtm_stringByUnescapingFromHTML()),
            let floorIDString = resultDict["pid"] as? String,
            let floorID = Int(floorIDString) else { return nil }

        DDLogDebug("First Quote Floor ID: \(floorID)")

        return floorID
    }
}
