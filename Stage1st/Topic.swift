//
//  Topic.swift
//  Stage1st
//
//  Created by Zheng Li on 5/20/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack

extension S1Topic {

    /**
     Update current topic, which should be traced topic generated from database with information from network API.

     - parameter topic: the topic holding information from network API.
     */
    func update(topic: S1Topic) {
        guard !self.isImmutable else {
            DDLogError("[S1Topic] Trying to update a immutable topic")
            assert(false)
            return
        }

        guard self.topicID.integerValue == topic.topicID.integerValue else {
            DDLogError("[S1Topic] Trying to update from a topic with different ID")
            assert(false)
            return
        }

        // Recored database reply count for presenting in topic list table cell
        self.lastReplyCount = self.replyCount

        let properties = ["title", "replyCount", "totalPageCount", "authorUserID", "authorUserName", "formhash", "message", "fID"]
        properties.forEach { (onePropertyName) in
            let localValue = self.valueForKey(onePropertyName)
            let serverValue = topic.valueForKey(onePropertyName)

            if serverValue == nil || S1Utility.valuesAreEqual(localValue, serverValue) {
                return
            }
            self.setValue(serverValue, forKey: onePropertyName)
        }
    }
}
