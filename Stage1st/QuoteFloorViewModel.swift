//
//  FloorViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import TextAttributes

struct FloorPresenting {
    let avatarURL: NSURL
    let author: NSAttributedString
    let dateTime: NSAttributedString
    let isTopicAuthor: Bool
    let floorMark: NSAttributedString
    let content: NSAttributedString


    init(floor: S1Floor, topic: S1Topic, baseURL: NSURL) {
        avatarURL = NSURL()
        let authorAttributes = TextAttributes().font(UIFont.systemFontOfSize(14.0)).foregroundColor(APColorManager.sharedInstance.colorForKey("quote.tableview.cell.title"))
        author = NSAttributedString(string: floor.author ?? "?", attributes: authorAttributes)

        if let topicAuthorID = topic.authorUserID, floorAuthorID = floor.authorID where topicAuthorID.isEqualToNumber(floorAuthorID) {
            isTopicAuthor = true
        } else {
            isTopicAuthor = false
        }

        dateTime = NSAttributedString(string: floor.postTime?.s1_gracefulDateTimeString() ?? "?", attributes: authorAttributes)
        floorMark = NSAttributedString(string: floor.indexMark ?? "#?", attributes: authorAttributes)
        let contentHTML = S1ContentViewModel.generateContentPage([floor], withTopic: topic)
        content = NSAttributedString(HTMLData: (contentHTML).dataUsingEncoding(NSUTF8StringEncoding), baseURL: baseURL, documentAttributes: nil)
    }
}

final class QuoteFloorViewModel {
    let manager: DiscuzAPIManager
    let topic: S1Topic
    let floors: [S1Floor]
    let baseURL: NSURL

    init(manager: DiscuzAPIManager, topic: S1Topic, floors: [S1Floor], baseURL: NSURL) {
        self.manager = manager
        self.topic = topic
        self.floors = floors
        self.baseURL = baseURL
    }

    func presenting(at indexPath: NSIndexPath) -> FloorPresenting {
        return FloorPresenting(floor: floors[indexPath.row], topic: topic, baseURL: baseURL)
    }

    func numberOfSection() -> Int {
        return 1
    }

    func numberOfRow(`in` section: Int) -> Int {
        return floors.count
    }
}
