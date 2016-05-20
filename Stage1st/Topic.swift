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
            return
        }

        guard self.topicID.integerValue == topic.topicID.integerValue else {
            DDLogError("[S1Topic] Trying to update from a topic with different ID")
            return
        }


    }
}
