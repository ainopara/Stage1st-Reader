//
//  Topic.swift
//  Stage1st
//
//  Created by Zheng Li on 5/20/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import KissXML

extension S1Topic {

    convenience init?(rawTopic: RawTopicList.Variables.Thread, forumID: Int?) {

        guard let topicID = Int(rawTopic.tid) else {
            return nil
        }

        self.init(topicID: topicID as NSNumber)

        if let unescapedTitle = rawTopic.subject?.aibo_stringByUnescapingFromHTML() {
            self.title = unescapedTitle
        }

        if let replyCount = Int(rawTopic.replies ?? "0") {
            self.replyCount = max(0, replyCount) as NSNumber
        }

        if let forumID = forumID {
            fID = forumID as NSNumber
        }

        if let unwrappedUserID = rawTopic.authorid, let authorUserID = Int(unwrappedUserID) {
            self.authorUserID = authorUserID as NSNumber
        }

        self.authorUserName = rawTopic.author
        self.lastReplyDate = Date(timeIntervalSince1970: TimeInterval(Int(rawTopic.dblastpost) ?? 0))
    }

    convenience init?(rawFloorList: RawFloorList) {

        guard let rawVariables = rawFloorList.variables else {
            return nil
        }

        let rawTopic = rawVariables.thread

        guard let topicID = Int(rawTopic.tid) else {
            return nil
        }

        self.init(topicID: topicID as NSNumber)

        if let title = rawTopic.subject?.aibo_stringByUnescapingFromHTML() {
            self.title = title
        }

        if let authorUserID = Int(rawTopic.authorid) {
            self.authorUserID = authorUserID as NSNumber
        }

        self.authorUserName = rawTopic.author

        self.formhash = rawVariables.formhash

        if let fID = Int(rawTopic.fid) {
            self.fID = fID as NSNumber
        }

        if let replyCount = Int(rawTopic.replies) {
            self.replyCount = max(0, replyCount) as NSNumber
        }

        self.message = rawFloorList.message?.description
    }

    convenience init?(element: DDXMLElement) {
        let links = (try? element.elements(for: ".//a[@target='_blank']")) ?? []

        guard links.count == 3 || links.count == 2 else {
            return nil
        }

        let titlePart = links[0]
        let titleString = titlePart.recursiveText

        let url = titlePart.attribute(forName: "href")?.stringValue ?? ""
        guard let topicID = Parser.extractTopic(from: url)?.topicID else {
            return nil
        }

        let authorUserID: Int?
        let authorName: String

        if links.count == 3 {
            let authorPart = links[1]

            /// Try extracting authorUserID and authorName
            if let authorHomeURL = authorPart.attribute(forName: "href")?.stringValue {
                var theAuthorUserID: Int?

                /// First Attempt
                let hyphenSeparated = authorHomeURL.split(separator: "-")
                if hyphenSeparated.count > 3 {
                    let thirdPart = hyphenSeparated[2]
                    if let authorUserIDString = thirdPart.split(separator: ".").first {
                        theAuthorUserID = Int(authorUserIDString)
                    }
                }

                /// Second Attempt
                if theAuthorUserID == nil || theAuthorUserID == 0 {
                    let queries = Parser.extractQuerys(from: authorHomeURL)
                    if let authorUserIDString = queries["uid"] {
                        theAuthorUserID = Int(authorUserIDString)
                    }
                }

                authorName = authorPart.firstText ?? ""
                authorUserID = theAuthorUserID
            } else {
                authorName = ""
                authorUserID = nil
            }

        } else {
            authorName = ""
            authorUserID = nil
        }

        /// Try extracting fid
        var fieldID: Int?
        let fieldIDPart = links.count == 3 ? links[2] : links[1]
        if let fieldURL = fieldIDPart.attribute(forName: "href")?.stringValue {
            /// First Attempt
            let hyphenSeperated = fieldURL.split(separator: "-")
            if hyphenSeperated.count > 2 {
                fieldID = Int(hyphenSeperated[1])
            }

            /// Second Attempt
            if fieldID == nil || fieldID == 0 {
                let queries = Parser.extractQuerys(from: fieldURL)
                if let fieldIDString = queries["fid"] {
                    fieldID = Int(fieldIDString)
                }
            }
        }

        /// Try extracting reply count
        var replyCount: Int = 0
        if
            let replyCountPart = (try? element.elements(for: ".//p[@class='xg1']"))?.first,
            let replyCountString = replyCountPart.firstText?.split(separator: " ").first,
            let extractedReplyCount = Int(replyCountString)
        {
            replyCount = extractedReplyCount
        }

        self.init(topicID: topicID)

        self.title = titleString
        self.authorUserID = authorUserID as NSNumber?
        self.authorUserName = authorName
        self.fID = fieldID as NSNumber?
        self.replyCount = replyCount as NSNumber
    }

    /**
     Update current topic, which should be traced topic generated from database with information from network API.

     - parameter topic: the topic holding information from network API.
     */
    func update(_ topic: S1Topic) {
        guard !isImmutable else {
            S1LogError("[S1Topic] Trying to update a immutable topic")
            assert(false)
            return
        }

        guard topicID.intValue == topic.topicID.intValue else {
            S1LogError("[S1Topic] Trying to update from a topic with different ID")
            assert(false)
            return
        }

        // Recored database reply count for presenting in topic list table cell
        lastReplyCount = replyCount

        let properties = ["title", "replyCount", "authorUserID", "authorUserName", "formhash", "message", "fID", "lastReplyDate"]
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
