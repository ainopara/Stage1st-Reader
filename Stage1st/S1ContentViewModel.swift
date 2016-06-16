//
//  S1ContentViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

// MARK: - Quote Floor
extension S1ContentViewModel {

    func searchFloorInCache(floorID: Int) -> S1Floor? {
        guard floorID != 0 else {
            return nil
        }

        return self.dataCenter.searchFloorInCacheByFloorID(floorID)
    }

    func chainSearchQuoteFloorInCache(firstFloorID: Int) -> [S1Floor] {
        var result: [S1Floor] = []
        var nextFloorID = firstFloorID
        while let floor = self.searchFloorInCache(nextFloorID) {
            result.insert(floor, atIndex: 0)
            if let quoteFloorID = floor.firstQuoteReplyFloorID as? Int {
                nextFloorID = quoteFloorID
            } else {
                return result
            }
        }

        return result
    }

    static func templateBundle() -> NSBundle {
        let templateBundleURL = NSBundle.mainBundle().URLForResource("WebTemplate", withExtension: "bundle")!
        return NSBundle.init(URL: templateBundleURL)!
    }

    static func pageBaseURL() -> NSURL {
        return self.templateBundle().URLForResource("ThreadTemplate", withExtension: "html", subdirectory: "html")!
    }
}

// MARK: - ToolBar
extension S1ContentViewModel {
    func forwardButtonImage() -> UIImage {
        if self.dataCenter.hasPrecacheFloorsForTopic(self.topic, withPage: self.currentPage + 1) {
            return UIImage(named: "Forward-Cached")!
        } else {
            return UIImage(named: "Forward")!
        }
    }

    func backwardButtonImage() -> UIImage {
        if self.dataCenter.hasPrecacheFloorsForTopic(self.topic, withPage: self.currentPage - 1) {
            return UIImage(named: "Back-Cached")!
        } else {
            return UIImage(named: "Back")!
        }
    }

    func favoriteButtonImage() -> UIImage {
        if let isFavorited = self.topic.favorite where isFavorited.boolValue {
            return UIImage(named: "Favorited")!
        }
        return UIImage(named: "Favorite")!
    }

    func pageButtonString() -> String {
        let totalPages = self.currentPage > self.totalPages ? self.currentPage : self.totalPages
        return "\(self.currentPage)/\(totalPages)"
    }
}

// MARK: - NSUserActivity
extension S1ContentViewModel {
    func correspondingWebPageURL() -> NSURL? {
        guard let baseURL = NSUserDefaults.standardUserDefaults().objectForKey("BaseURL") as? String else { return nil }
        return NSURL(string: "\(baseURL)thread-\(self.topic.topicID)-\(self.currentPage)-1.html")
    }

    func activityTitle() -> String? {
        return self.topic.title
    }

    func activityUserInfo() -> [NSObject: AnyObject] {
        return [
            "topicID": self.topic.topicID,
            "page": self.currentPage
        ]
    }
}

// MARK: - Actions
extension S1ContentViewModel {
    func toggleFavorite() {
        if let isFavorite = self.topic.favorite where isFavorite.boolValue {
            self.topic.favorite = false
        } else {
            self.topic.favorite = true
            self.topic.favoriteDate = NSDate()
        }
    }
}
