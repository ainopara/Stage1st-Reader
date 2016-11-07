//
//  S1ContentViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import CocoaLumberjack
import Result
import Mustache
import ReactiveSwift

class S1ContentViewModel: NSObject {
    let topic: S1Topic
    let dataCenter: S1DataCenter

    let currentPage: MutableProperty<UInt>
    let previousPage: MutableProperty<UInt>
    let totalPages: MutableProperty<UInt>
    var cachedViewPosition: [UInt: Double] = [:]

    init(topic: S1Topic, dataCenter: S1DataCenter) {
        self.topic = topic.isImmutable ? topic : (topic.copy() as! S1Topic)

        if let currentPage = topic.lastViewedPage?.uintValue {
            self.currentPage = MutableProperty(currentPage)
        } else {
            self.currentPage = MutableProperty(1)
        }

        self.previousPage = MutableProperty(self.currentPage.value)

        if let replyCount = topic.replyCount?.uintValue {
            self.totalPages = MutableProperty(replyCount / 30 + 1)
        } else {
            self.totalPages = MutableProperty(self.currentPage.value)
        }

        DDLogInfo("[ContentVM] Initialize with TopicID: \(topic.topicID)")

        self.dataCenter = dataCenter

        super.init()

        if topic.favorite == nil {
            topic.favorite = NSNumber(value: false)
        }

        if let lastViewedPosition = topic.lastViewedPosition?.doubleValue, let lastViewedPage = topic.lastViewedPage?.uintValue {
            cachedViewPosition[lastViewedPage] = lastViewedPosition
        }
    }

}

extension S1ContentViewModel {
    func currentContentPage(completion: @escaping (Result<(String, Bool), NSError>) -> Void) {
        dataCenter.floors(for: topic, withPage: NSNumber(value: currentPage.value), success: { [weak self] (floors, isFromCache) in
            guard let strongSelf = self else { return }
            let shouldRefetch = isFromCache && floors.count != 30 && !strongSelf.isInLastPage()
            completion(.success(strongSelf.generatePage(with: floors), shouldRefetch))
        }) { (error) in
            completion(.failure(error as NSError))
        }
    }
}

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
        return self.templateBundle().url(forResource: "blank", withExtension: "html", subdirectory: "html")!
    }
}

// MARK: - ToolBar
extension S1ContentViewModel {
    func hasPrecachedPreviousPage() -> Bool {
        return dataCenter.hasPrecacheFloors(for: topic, withPage: NSNumber(value: currentPage.value - 1))
    }

    func hasPrecachedNextPage() -> Bool {
        return dataCenter.hasPrecacheFloors(for: topic, withPage: NSNumber(value: currentPage.value + 1))
    }

    func forwardButtonImage() -> UIImage {
        if self.dataCenter.hasPrecacheFloors(for: self.topic, withPage: NSNumber(value: self.currentPage.value + 1)) {
            return UIImage(named: "Forward-Cached")!
        } else {
            return UIImage(named: "Forward")!
        }
    }

    func backwardButtonImage() -> UIImage {
        if self.dataCenter.hasPrecacheFloors(for: self.topic, withPage: NSNumber(value: self.currentPage.value - 1)) {
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
        let presentingTotalPages = max(self.currentPage.value, self.totalPages.value)
        return "\(self.currentPage.value)/\(presentingTotalPages)"
    }
}

// MARK: - NSUserActivity
extension S1ContentViewModel {
    func correspondingWebPageURL() -> URL? {
        guard let baseURL = UserDefaults.standard.object(forKey: "BaseURL") as? String else { return nil }
        return URL(string: "\(baseURL)thread-\(self.topic.topicID)-\(self.currentPage.value)-1.html")
    }

    func activityTitle() -> String? {
        return self.topic.title
    }

    func activityUserInfo() -> [AnyHashable: Any] {
        return [
            "topicID": self.topic.topicID,
            "page": self.currentPage.value
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
        self.cachedViewPosition[self.currentPage.value] = Double(offset)
    }

    func cacheOffsetForPreviousPage(_ offset: CGFloat) {
        self.cachedViewPosition[self.previousPage.value] = Double(offset)
    }

    func cachedOffsetForCurrentPage() -> Double? {
        return self.cachedViewPosition[self.currentPage.value]
    }
}

// MARK: - View Model

extension S1ContentViewModel {
    func reportComposeViewModel(floor: Floor) -> ReportComposeViewModel {
        return ReportComposeViewModel(apiManager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), topic: topic, floor: floor)
    }
}

extension S1ContentViewModel: QuoteFloorViewModelGenerator {
    func quoteFloorViewModel(floors: [Floor], centerFloorID: Int) -> QuoteFloorViewModel {
        return QuoteFloorViewModel(manager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), topic: topic.copy() as! S1Topic, floors: floors, centerFloorID: centerFloorID, baseURL: type(of: self).pageBaseURL())
    }
}

extension S1ContentViewModel: UserViewModelGenerator {
    func userViewModel(userID: Int) -> UserViewModel {
        return UserViewModel(manager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), user: User(ID: userID, name: ""))
    }
}

// MARK: - Misc
extension S1ContentViewModel {
    func saveTopicViewedState(lastViewedPosition: Double?) {

        DDLogInfo("[ContentVM] Save Topic View State Begin")

        if let lastViewedPosition = lastViewedPosition {
            topic.lastViewedPosition = NSNumber(value: lastViewedPosition)
        } else if topic.lastViewedPosition == nil || topic.lastViewedPage?.uintValue ?? 0 != currentPage.value {
            topic.lastViewedPosition = NSNumber(value: 0.0)
        }

        topic.lastViewedPage = NSNumber(value: currentPage.value)
        topic.lastViewedDate = Date()
        topic.lastReplyCount = topic.replyCount
        dataCenter.hasViewed(topic)

        DDLogInfo("[ContentVM] Save Topic View State Finish")
    }

    func cancelRequest() {
        dataCenter.cancelRequest()
    }

    func isInFirstPage() -> Bool {
        return currentPage.value == 1
    }
    func isInLastPage() -> Bool {
        return currentPage.value >= totalPages.value
    }
}

// MARK: - Page Rander
extension S1ContentViewModel: PageRenderer { }
