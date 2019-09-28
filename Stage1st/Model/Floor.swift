//
//  Floor.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Html

public struct Floor: Codable {
    public let id: Int
    public let author: User
    public var indexMark: String?

    public var creationDate: Date?
    public var content: String = ""
    public var attachments: [String: URL] = [:]
    public var inlinedAttachmentIDs: [String] = []

    public var floatingAttachments: [String: URL] {
        return attachments.filter { (key, value) in !inlinedAttachmentIDs.contains(key) }
    }

    public init(id: Int, author: User) {
        self.id = id
        self.author = author
    }
}

extension Floor {
    init?(rawPost: RawFloorList.Variables.Post) {
        guard
            let id = Int(rawPost.pid),
            let authorID = Int(rawPost.authorid)
        else { return nil }

        self.id = id
        self.author = User(id: authorID, name: rawPost.author)
        self.indexMark = rawPost.number
        self.creationDate = Date(timeIntervalSince1970: TimeInterval(rawPost.dbdateline) ?? 0)
        self.content = rawPost.message ?? ""
        self.attachments = (rawPost.attachments ?? [:]).mapValues({ (attachment) in
            return attachment.url.appendingPathComponent(attachment.attachment)
        })

        self.preprocess()
    }
}

extension Floor {
    mutating func preprocess() {
        content =
            render(ChildOf<Tag.Tr>.td(attributes: [.class("t_f"), .id("postmessage_\(id)")], .raw(content)))
            .s1_replace(
                pattern: "提示: <em>(.*?)</em>",
                with: render(Node.div(attributes: [.class("s1-alert")], .raw("$1")))
            )
            .s1_replace(
                pattern: "<blockquote><p>引用:</p>",
                with: "<blockquote>"
            )
            .s1_replace(
                pattern: "<imgwidth=([^>]*)>",
                with: "<img width=$1>"
            )
            .s1_replace(
                pattern: "\\[thgame_biliplay\\{,=av\\}(\\d+)\\{,=page\\}(\\d+)[^\\]]*\\]\\[/thgame_biliplay\\]",
                with: render(Node.a(attributes: [.href("https://www.bilibili.com/video/av$1/index_$2.html")], .raw("https://www.bilibili.com/video/av$1/index_$2.html")))
            )

        guard
            attachments.count > 0,
            let re = try? NSRegularExpression(pattern: "\\[attach\\]([\\d]*)\\[/attach\\]", options: [.dotMatchesLineSeparators])
        else {
            return
        }

        let contentAsNSString = content as NSString
        let range = NSRange(location: 0, length: contentAsNSString.length)

        var replaceList = [(String, String)]()

        re.enumerateMatches(in: content, options: [], range: range) { (result, flags, stop) in
            guard let result = result else { return }
            let attachmentID = contentAsNSString.substring(with: result.range(at: 1))
            guard let attachmentURL = self.attachments[attachmentID] else { return }
            let imageNode = render(Node.img(attributes: [.src(attachmentURL.absoluteString)]))
            replaceList.append(("[attach]" + attachmentID + "[/attach]", imageNode))
            inlinedAttachmentIDs.append(attachmentID)
        }

        for replacePair in replaceList {
            content = content.replacingOccurrences(of: replacePair.0, with: replacePair.1)
        }
    }
}

public extension Floor {
    var firstQuoteReplyFloorID: Int? {
        guard
            let urlString = S1Global.regexExtract(from: content, withPattern: "<div class=\"quote\"><blockquote><a href=\"([^\"]*)\"", andColums: [1]).first,
            let floorIDString = Parser.extractQuerys(from: urlString.aibo_stringByUnescapingFromHTML())["pid"],
            let floorID = Int(floorIDString)
        else {
            return nil
        }

        S1LogDebug("First Quote Floor ID: \(floorID)")
        return floorID
    }
}
