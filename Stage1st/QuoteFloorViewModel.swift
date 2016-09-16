//
//  FloorViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import TextAttributes

struct FloorPresenting {
    let avatarURL: URL?
    let author: NSAttributedString
    let dateTime: NSAttributedString
    let isTopicAuthor: Bool
    let floorMark: NSAttributedString
    let content: NSAttributedString


    init(floor: Floor, topic: S1Topic, baseURL: URL) {
        avatarURL = floor.author.avatarURL
        let authorAttributes = TextAttributes().font(UIFont.systemFont(ofSize: 14.0)).foregroundColor(APColorManager.sharedInstance.colorForKey("quote.tableview.cell.title"))
        author = NSAttributedString(string: floor.author.name, attributes: authorAttributes)

        if let topicAuthorID = topic.authorUserID as? Int, topicAuthorID == floor.author.ID {
            isTopicAuthor = true
        } else {
            isTopicAuthor = false
        }

        dateTime = NSAttributedString(string: floor.creationDate?.s1_gracefulDateTimeString() ?? "?", attributes: authorAttributes)
        floorMark = NSAttributedString(string: floor.indexMark ?? "#?", attributes: authorAttributes)
        let contentHTML = S1ContentViewModel.generateContentPage([floor], with: topic)
        content = NSAttributedString(htmlData: (contentHTML).data(using: String.Encoding.utf8), baseURL: baseURL, documentAttributes: nil)
    }
}

final class QuoteFloorViewModel {
    let manager: DiscuzAPIManager
    let topic: S1Topic
    let floors: [Floor]
    let htmlString: String
    let centerFloorID: Int
    let baseURL: URL

    init(manager: DiscuzAPIManager, topic: S1Topic, floors: [Floor], htmlString: String, centerFloorID: Int, baseURL: URL) {
        self.manager = manager
        self.topic = topic
        self.floors = floors
        self.htmlString = htmlString
        self.centerFloorID = centerFloorID
        self.baseURL = baseURL
    }

    func presenting(at indexPath: IndexPath) -> FloorPresenting {
        return FloorPresenting(floor: floors[(indexPath as NSIndexPath).row], topic: topic, baseURL: baseURL)
    }

    func numberOfSection() -> Int {
        return 1
    }

    func numberOfRow(in section: Int) -> Int {
        return floors.count
    }
}
