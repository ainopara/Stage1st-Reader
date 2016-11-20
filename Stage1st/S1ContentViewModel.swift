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
import ReactiveCocoa
import ReactiveSwift

class S1ContentViewModel: NSObject, PageRenderer {
    let topic: S1Topic
    let dataCenter: S1DataCenter
    let discuzAPIManager = DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b")

    let currentPage: MutableProperty<UInt>
    let previousPage: MutableProperty<UInt>
    let totalPages: MutableProperty<UInt>

    let title: DynamicProperty<NSString>
    let replyCount: DynamicProperty<NSNumber>
    let favorite: DynamicProperty<NSNumber>

    var cachedViewPosition: [UInt: Double] = [:]

    init(topic: S1Topic, dataCenter: S1DataCenter) {
        self.topic = topic.isImmutable ? (topic.copy() as! S1Topic) : topic

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

        self.title = DynamicProperty(object: self.topic, keyPath: #keyPath(S1Topic.title))
        self.replyCount = DynamicProperty(object: self.topic, keyPath: #keyPath(S1Topic.replyCount))
        self.favorite = DynamicProperty(object: self.topic, keyPath: #keyPath(S1Topic.favorite))

        super.init()

        if topic.favorite == nil {
            topic.favorite = NSNumber(value: false)
        }

        if let lastViewedPosition = topic.lastViewedPosition?.doubleValue, let lastViewedPage = topic.lastViewedPage?.uintValue {
            cachedViewPosition[lastViewedPage] = lastViewedPosition
        }

        currentPage.producer.startWithValues { (page) in
            DDLogInfo("[ContentVM] Current page changed to: \(page)")
        }

        totalPages <~ replyCount.producer
            .map { (($0?.uintValue) ?? 0 as UInt) / 30 + 1 }
            .logEvents()
        // TODO: Add logs.
//        DDLogInfo("[ContentVM] reply count changed: %@", x)
        previousPage <~ currentPage.combinePrevious(1).producer.map { (previous, current) in return previous }
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

    func hasPrecachedCurrentPage() -> Bool {
        return dataCenter.hasPrecacheFloors(for: topic, withPage: NSNumber(value: currentPage.value))
    }

    func hasPrecachedNextPage() -> Bool {
        return dataCenter.hasPrecacheFloors(for: topic, withPage: NSNumber(value: currentPage.value + 1))
    }

    func forwardButtonImage() -> UIImage {
        if self.dataCenter.hasPrecacheFloors(for: self.topic, withPage: NSNumber(value: self.currentPage.value + 1)) {
            return #imageLiteral(resourceName: "Forward-Cached")
        } else {
            return #imageLiteral(resourceName: "Forward")
        }
    }

    func backwardButtonImage() -> UIImage {
        if self.dataCenter.hasPrecacheFloors(for: self.topic, withPage: NSNumber(value: self.currentPage.value - 1)) {
            return #imageLiteral(resourceName: "Back-Cached")
        } else {
            return #imageLiteral(resourceName: "Back")
        }
    }

    func favoriteButtonImage() -> UIImage {
        if let isFavorited = self.topic.favorite, isFavorited.boolValue {
            return #imageLiteral(resourceName: "Favorited")
        } else {
            return #imageLiteral(resourceName: "Favorite")
        }
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
            topic.favorite = false
        } else {
            topic.favorite = true
            topic.favoriteDate = Date()
        }
    }
}

// MARK: - Cache Page Offset
extension S1ContentViewModel {
    func cacheOffsetForCurrentPage(_ offset: CGFloat) {
        cachedViewPosition[currentPage.value] = Double(offset)
    }

    func cacheOffsetForPreviousPage(_ offset: CGFloat) {
        cachedViewPosition[previousPage.value] = Double(offset)
    }

    func cachedOffsetForCurrentPage() -> Double? {
        return cachedViewPosition[currentPage.value]
    }
}

// MARK: - View Model
extension S1ContentViewModel {
    func reportComposeViewModel(floor: Floor) -> ReportComposeViewModel {
        return ReportComposeViewModel(apiManager: discuzAPIManager,
                                      topic: topic,
                                      floor: floor)
    }
}

extension S1ContentViewModel: QuoteFloorViewModelGenerator {
    func quoteFloorViewModel(floors: [Floor], centerFloorID: Int) -> QuoteFloorViewModel {
        return QuoteFloorViewModel(dataCenter: dataCenter,
                                   manager: discuzAPIManager,
                                   topic: topic,
                                   floors: floors,
                                   centerFloorID: centerFloorID,
                                   baseURL: type(of: self).pageBaseURL())
    }
}

extension S1ContentViewModel: UserViewModelGenerator {
    func userViewModel(userID: Int) -> UserViewModel {
        return UserViewModel(manager: discuzAPIManager,
                             user: User(ID: userID, name: ""))
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
