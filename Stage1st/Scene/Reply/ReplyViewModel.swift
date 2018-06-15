//
//  ReplyViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/6/15.
//  Copyright © 2018 Renaissance. All rights reserved.
//

final class ReplyViewModel {
    enum ReplyTarget {
        case topic
        case floor(Floor, page: Int)
    }
    let topic: S1Topic
    let target: ReplyTarget

    init(topic: S1Topic, target: ReplyTarget) {
        self.topic = topic
        self.target = target
    }
}

extension Notification.Name {
    static let ReplyDidPosted = Notification.Name.init(rawValue: "ReplyDidPostedNotification")
}
