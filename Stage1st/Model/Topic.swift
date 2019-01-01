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

    convenience init?(rawTopic: RawTopicList.Variables.Thread, fieldID: Int?) {
        guard let topicID = Int(rawTopic.tid) else {
            return nil
        }

        self.init(topicID: topicID as NSNumber)

        if let unescapedTitle = (rawTopic.subject as NSString).gtm_stringByUnescapingFromHTML() {
            self.title = unescapedTitle
        }

        if let replyCount = Int(rawTopic.replies) {
            self.replyCount = max(0, replyCount) as NSNumber
        }

        if let fieldID = fieldID {
            fID = fieldID as NSNumber
        }

        if let authorUserID = Int(rawTopic.authorid) {
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

        if let unescapedTitle = (rawTopic.subject as NSString).gtm_stringByUnescapingFromHTML() {
            self.title = unescapedTitle
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
        guard let topicID = S1Parser.extractTopicInfo(fromLink: url)?.topicID else {
            return nil
        }

        let authorUserID: Int?
        let authorName: String

        if links.count == 3 {
            let authorPart = links[1]

            guard let authorHomeURL = authorPart.attribute(forName: "href")?.stringValue else {
                return nil
            }

            guard let theAuthorUserID = Int(authorHomeURL.split(separator: "-")[2].split(separator: ".")[0]) else {
                return nil
            }

            authorName = authorPart.firstText ?? ""
            authorUserID = theAuthorUserID
        } else {
            authorName = ""
            authorUserID = nil
        }

        let fieldIDPart = links.count == 3 ? links[2] : links[1]
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
        self.authorUserID = authorUserID as NSNumber?
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
