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

    func searchFloorInCache(_ floorID: Int) -> Floor? {
        guard floorID != 0 else {
            return nil
        }

        return self.dataCenter.searchFloorInCache(byFloorID: NSNumber(value: floorID))
    }

    func chainSearchQuoteFloorInCache(_ firstFloorID: Int) -> [Floor] {
        var result: [Floor] = []
        var nextFloorID = firstFloorID
        while let floor = self.searchFloorInCache(nextFloorID) {
            result.insert(floor, at: 0)
            if let quoteFloorID = floor.firstQuoteReplyFloorID {
                nextFloorID = quoteFloorID
            } else {
                return result
            }
        }

        return result
    }

    static func templateBundle() -> Bundle {
        let templateBundleURL = Bundle.main.url(forResource: "WebTemplate", withExtension: "bundle")!
        return Bundle.init(url: templateBundleURL)!
    }

    static func pageBaseURL() -> URL {
        return self.templateBundle().url(forResource: "ThreadTemplate", withExtension: "html", subdirectory: "html")!
    }
}

// MARK: - ToolBar
extension S1ContentViewModel {
    func forwardButtonImage() -> UIImage {
        if self.dataCenter.hasPrecacheFloors(for: self.topic, withPage: NSNumber(value: self.currentPage + 1)) {
            return UIImage(named: "Forward-Cached")!
        } else {
            return UIImage(named: "Forward")!
        }
    }

    func backwardButtonImage() -> UIImage {
        if self.dataCenter.hasPrecacheFloors(for: self.topic, withPage: NSNumber(value: self.currentPage - 1)) {
            return UIImage(named: "Back-Cached")!
        } else {
            return UIImage(named: "Back")!
        }
    }

    func favoriteButtonImage() -> UIImage {
        if let isFavorited = self.topic.favorite, isFavorited.boolValue {
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
    func correspondingWebPageURL() -> URL? {
        guard let baseURL = UserDefaults.standard.object(forKey: "BaseURL") as? String else { return nil }
        return URL(string: "\(baseURL)thread-\(self.topic.topicID)-\(self.currentPage)-1.html")
    }

    func activityTitle() -> String? {
        return self.topic.title
    }

    func activityUserInfo() -> [AnyHashable: Any] {
        return [
            "topicID": self.topic.topicID,
            "page": self.currentPage
        ]
    }
}

// MARK: - Actions
extension S1ContentViewModel {
    func toggleFavorite() {
        if let isFavorite = self.topic.favorite, isFavorite.boolValue {
            self.topic.favorite = false
        } else {
            self.topic.favorite = true
            self.topic.favoriteDate = Date()
        }
    }
}

// MARK: - Cache Page Offset
extension S1ContentViewModel {
    func cacheOffsetForCurrentPage(_ offset: CGFloat) {
        self.cachedViewPosition[self.currentPage as NSNumber] = Double(offset)
    }

    func cacheOffsetForPreviousPage(_ offset: CGFloat) {
        self.cachedViewPosition[self.previousPage as NSNumber] = Double(offset)
    }

    func cachedOffsetForCurrentPage() -> NSNumber? {
        return self.cachedViewPosition[self.currentPage as NSNumber] as? NSNumber
    }
}

extension S1ContentViewModel {
    func reportComposeViewModel(_ floor: Floor) -> ReportComposeViewModel {
        return ReportComposeViewModel(apiManager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), topic: topic, floor: floor)
    }
}
