//
//  Floor.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import SwiftyJSON
import CocoaLumberjack

private let kFloorID = "floorID"
private let kIndexMark = "indexMark"
private let kAuthor = "author"
private let kAuthorID = "authorID"
private let kPostTime = "postTime"
private let kContent = "content"
private let kPoll = "poll"
private let kMessage = "message"
private let kImageAttachmentURLStringList = "imageAttachmentList"
private let kFirstQuoteReplyFloorID = "firstQuoteReplyFloorID"

#if swift(>=4.0)
@objcMembers
#endif
public final class Floor: NSObject, NSCoding {
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
        guard let IDString = json["pid"].string,
            let ID = Int(IDString),
            let authorIDString = json["authorid"].string,
            let authorID = UInt(authorIDString),
            let authorName = json["author"].string else {
            return nil
        }

        self.ID = ID
        author = User(ID: authorID, name: authorName)

        super.init()
        // FIXME: finish this.
    }

    public required init?(coder aDecoder: NSCoder) {
        let ID = aDecoder.decodeObject(forKey: kFloorID) as? Int ?? aDecoder.decodeInteger(forKey: kFloorID)
        let authorID = aDecoder.decodeObject(forKey: kAuthorID) as? UInt ?? UInt(aDecoder.decodeInteger(forKey: kAuthorID))
        guard ID != 0,
            authorID != 0,
            let authorName = aDecoder.decodeObject(forKey: kAuthor) as? String else {
            return nil
        }

        self.ID = ID
        author = User(ID: authorID, name: authorName)

        super.init()

        indexMark = aDecoder.decodeObject(forKey: kIndexMark) as? String

        creationDate = aDecoder.decodeObject(forKey: kPostTime) as? Date
        content = aDecoder.decodeObject(forKey: kContent) as? String
        message = aDecoder.decodeObject(forKey: kMessage) as? String
        imageAttachmentURLStringList = aDecoder.decodeObject(forKey: kImageAttachmentURLStringList) as? [String]
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(ID, forKey: kFloorID)
        aCoder.encode(indexMark, forKey: kIndexMark)
        aCoder.encode(author.name, forKey: kAuthor)
        aCoder.encode(author.ID, forKey: kAuthorID)
        aCoder.encode(creationDate, forKey: kPostTime)
        aCoder.encode(content, forKey: kContent)
        aCoder.encode(message, forKey: kMessage)
        aCoder.encode(imageAttachmentURLStringList, forKey: kImageAttachmentURLStringList)
    }
}

extension Floor {
    var firstQuoteReplyFloorID: Int? {
        guard let content = self.content,
            let URLString = S1Global.regexExtract(from: content, withPattern: "<div class=\"quote\"><blockquote><a href=\"([^\"]*)\"", andColums: [1]).first as? String,
            let resultDict = S1Parser.extractQuerys(fromURLString: URLString.gtm_stringByUnescapingFromHTML()),
            let floorIDString = resultDict["pid"],
            let floorID = Int(floorIDString) else {
            return nil
        }

        DDLogDebug("First Quote Floor ID: \(floorID)")
        return floorID
    }
}
