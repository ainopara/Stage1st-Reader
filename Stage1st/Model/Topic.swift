//
//  Topic.swift
//  Stage1st
//
//  Created by Zheng Li on 5/20/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import SwiftyJSON
import KissXML

extension S1Topic {

    convenience init?(json: JSON, fieldID: Int?) {
        guard let topicID = json["tid"].string.flatMap({ Int($0) }) else {
            return nil
        }

        self.init(topicID: topicID as NSNumber)

        if
            let title = json["subject"].string.flatMap({ $0 as NSString }),
            let unescapedTitle = title.gtm_stringByUnescapingFromHTML()
        {
            self.title = unescapedTitle
        }

        if let replyCount = json["replies"].string.flatMap({ Int($0) }) {
            self.replyCount = max(0, replyCount) as NSNumber
        }

        if let fieldID = fieldID {
            fID = NSNumber(value: fieldID)
        }

        if let authorUserID = json["authorid"].string.flatMap({ Int($0) }) {
            self.authorUserID = NSNumber(value: authorUserID)
        }

        if let authorUserName = json["author"].string {
            self.authorUserName = authorUserName
        }

        if let lastPostDate = json["dblastpost"].string.flatMap({ Date(timeIntervalSince1970: TimeInterval(Int($0) ?? 0)) }) {
            lastReplyDate = lastPostDate
        }
    }

    convenience init?(element: DDXMLElement) {
        let links = (try? element.elements(for: ".//a[@target='_blank']")) ?? []

        guard links.count == 3 else {
            return nil
        }

        let titlePart = links[0]
        let titleString = titlePart.recursiveText

        let url = titlePart.attribute(forName: "href")?.stringValue ?? ""
        guard let topicID = S1Parser.extractTopicInfo(fromLink: url)?.topicID else {
            return nil
        }

        let authorPart = links[1]
        let authorName = authorPart.firstText ?? ""

        guard let authorHomeURL = authorPart.attribute(forName: "href")?.stringValue else {
            return nil
        }

        guard let authorUserID = Int(authorHomeURL.split(separator: "-")[2].split(separator: ".")[0]) else {
            return nil
        }

        let fieldIDPart = links[2]
        guard let fieldURL = fieldIDPart.attribute(forName: "href")?.stringValue else {
            return nil
        }

        guard let fieldID = Int(fieldURL.split(separator: "-")[1]) else {
            return nil
        }

        guard let replyCountPart = (try? element.elements(for: ".//p[@class='xg1']"))?.first else {
            return nil
        }

        guard let replyCountString = replyCountPart.firstText?.split(separator: " ").first else {
            return nil
        }

        guard let replyCount = Int(replyCountString) else {
            return nil
        }

        self.init(topicID: topicID)

        self.title = titleString
        self.authorUserID = authorUserID as NSNumber
        self.authorUserName = authorName
        self.fID = fieldID as NSNumber
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
