//
//  Topic.swift
//  Stage1st
//
//  Created by Zheng Li on 5/20/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack
import SwiftyJSON

extension S1Topic {

    convenience init?(json: JSON, fieldID: UInt?) {
        guard let topicID = json["tid"].string.flatMap({ Int($0) }) else {
            return nil
        }

        self.init(topicID: topicID as NSNumber)

        if let title = json["subject"].string.flatMap({ $0 as NSString }),
            let unescapedTitle = title.gtm_stringByUnescapingFromHTML() {
            self.title = unescapedTitle
        }

        if let replyCount = json["replies"].string.flatMap({ Int($0) }) {
            self.replyCount = replyCount as NSNumber
        }

        if let fieldID = fieldID {
            self.fID = fieldID as NSNumber
        }

        if let authorUserID = json["authorid"].string.flatMap({ Int($0) }) {
            self.authorUserID = authorUserID as NSNumber
        }

        if let authorUserName = json["author"].string {
            self.authorUserName = authorUserName
        }

        if let lastPostDate = json["dblastpost"].string.flatMap({ Date(timeIntervalSince1970: TimeInterval(Int($0) ?? 0)) }) {
            self.lastReplyDate = lastPostDate
        }
    }

    /**
     Update current topic, which should be traced topic generated from database with information from network API.

     - parameter topic: the topic holding information from network API.
     */
    func update(_ topic: S1Topic) {
        guard !isImmutable else {
            DDLogError("[S1Topic] Trying to update a immutable topic")
            assert(false)
            return
        }

        guard topicID.intValue == topic.topicID.intValue else {
            DDLogError("[S1Topic] Trying to update from a topic with different ID")
            assert(false)
            return
        }

        // Recored database reply count for presenting in topic list table cell
        lastReplyCount = replyCount

        let properties = ["title", "replyCount", "totalPageCount", "authorUserID", "authorUserName", "formhash", "message", "fID", "lastReplyDate"]
        properties.forEach { onePropertyName in
            let localValue = self.value(forKey: onePropertyName)
            let serverValue = topic.value(forKey: onePropertyName)

            if serverValue == nil || valuesAreEqual(localValue as AnyObject?, serverValue as AnyObject?) {
                return
            }
            self.setValue(serverValue, forKey: onePropertyName)
        }

        // Always update message
        if message != topic.message {
            message = topic.message
        }
    }
}
