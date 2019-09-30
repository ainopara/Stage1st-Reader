//
//  ContentViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import CocoaLumberjack
import Alamofire
import Mustache
import ReactiveSwift
import ReactiveCocoa
import WebKit

class ContentViewModel: NSObject, PageRenderer {
    let topic: S1Topic
    var currentFloors: [Floor] = []
    var dataCenter: DataCenter { AppEnvironment.current.dataCenter }
    var apiManager: DiscuzClient { dataCenter.apiManager }

    let currentPage: MutableProperty<Int>
    let previousPage: MutableProperty<Int>
    let totalPages: MutableProperty<Int>

    let title: DynamicProperty<NSString?>
    let replyCount: DynamicProperty<NSNumber?>
    let favorite: DynamicProperty<NSNumber?>

    var cachedViewPosition = [Int: CGFloat]()

    // MARK: Initialize

    init(topic: S1Topic) {
        self.topic = topic.copy() as! S1Topic

        if let currentPage = topic.lastViewedPage?.intValue {
            self.currentPage = MutableProperty(max(currentPage, 1))
        } else {
            currentPage = MutableProperty(1)
        }

        previousPage = MutableProperty(currentPage.value)

        if let replyCount = topic.replyCount?.intValue {
            totalPages = MutableProperty(replyCount / 30 + 1)
        } else {
            totalPages = MutableProperty(currentPage.value)
        }

        S1LogInfo("[ContentVM] Initialize with TopicID: \(topic.topicID)")

        title = DynamicProperty(object: self.topic, keyPath: #keyPath(S1Topic.title))
        replyCount = DynamicProperty(object: self.topic, keyPath: #keyPath(S1Topic.replyCount))
        favorite = DynamicProperty(object: self.topic, keyPath: #keyPath(S1Topic.favorite))

        super.init()

        if topic.favorite == nil {
            topic.favorite = NSNumber(value: false)
        }

        if let lastViewedPosition = topic.lastViewedPosition?.doubleValue, let lastViewedPage = topic.lastViewedPage?.intValue {
            cachedViewPosition[lastViewedPage] = CGFloat(lastViewedPosition)
        }

        currentPage.producer.startWithValues { page in
            S1LogInfo("[ContentVM] Current page changed to: \(page)")
        }

        totalPages <~ replyCount.producer
            .map { ($0?.intValue ?? 0) / 30 + 1 }

        previousPage <~ currentPage.combinePrevious(currentPage.value).producer.map { arg in
            let (previous, _) = arg
            return previous
        }
    }

    func userIsBlocked(with userID: Int) -> Bool {
        return dataCenter.userIDIsBlocked(ID: userID)
    }
}

// MARK: - Network
extension ContentViewModel {
    func currentContentPage(completion: @escaping (Result<String, Error>) -> Void) {
        dataCenter.floors(for: topic, with: Int(currentPage.value)) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case let .success(floors, isFromCache):
                let shouldRefetch = isFromCache && floors.count != 30 && !strongSelf.isInLastPage()
                guard !shouldRefetch else {
                    strongSelf.dataCenter.removePrecachedFloors(for: strongSelf.topic, with: Int(strongSelf.currentPage.value))
                    strongSelf.currentContentPage(completion: completion)
                    return
                }

                strongSelf.currentFloors = floors

                completion(.success(strongSelf.generatePage(with: floors)))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Quote Floor
extension ContentViewModel {
    func searchFloorInCache(_ floorID: Int) -> Floor? {
        guard floorID != 0 else {
            return nil
        }

        return dataCenter.searchFloorInCache(by: floorID)
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

    func pageBaseURL() -> URL {
        return templateBundle().url(forResource: "blank", withExtension: "html", subdirectory: "html")!
    }
}

// MARK: - ToolBar
extension ContentViewModel {
    func hasPrecachedPreviousPage() -> Bool {
        return dataCenter.hasPrecachedFloors(for: Int(truncating: topic.topicID), page: currentPage.value - 1)
    }

    func hasValidPrecachedCurrentPage() -> Bool {
        if isInLastPage() {
            return dataCenter.hasPrecachedFloors(for: Int(truncating: topic.topicID), page: currentPage.value)
        } else {
            return dataCenter.hasFullPrecachedFloors(for: Int(truncating: topic.topicID), page: currentPage.value)
        }
    }

    func hasPrecachedNextPage() -> Bool {
        return dataCenter.hasPrecachedFloors(for: Int(truncating: topic.topicID), page: currentPage.value + 1)
    }

    func forwardButtonImage() -> UIImage {
        if dataCenter.hasPrecachedFloors(for: Int(truncating: topic.topicID), page: currentPage.value + 1) {
            return #imageLiteral(resourceName: "Forward-Cached")
        } else {
            return #imageLiteral(resourceName: "Forward")
        }
    }

    func backwardButtonImage() -> UIImage {
        if dataCenter.hasPrecachedFloors(for: Int(truncating: topic.topicID), page: currentPage.value - 1) {
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
        let presentingTotalPages = max(currentPage.value, totalPages.value)
        return "\(self.currentPage.value)/\(presentingTotalPages)"
    }
}

// MARK: - NSUserActivity
extension ContentViewModel {
    func correspondingWebPageURL() -> URL? {
        return URL(string: "\(AppEnvironment.current.serverAddress.main)/thread-\(self.topic.topicID)-\(self.currentPage.value)-1.html")
    }

    func activityTitle() -> String? {
        return topic.title
    }

    func activityUserInfo() -> [AnyHashable: Any] {
        return [
            "topicID": self.topic.topicID,
            "page": self.currentPage.value,
        ]
    }
}

// MARK: - Actions
extension ContentViewModel {
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
extension ContentViewModel {
    func cacheOffsetForCurrentPage(_ offset: CGFloat) {
        cachedViewPosition[currentPage.value] = offset
    }

    func cacheOffsetForPreviousPage(_ offset: CGFloat) {
        cachedViewPosition[previousPage.value] = offset
    }

    func cachedOffsetForCurrentPage() -> CGFloat? {
        return cachedViewPosition[currentPage.value]
    }
}

// MARK: - View Model
extension ContentViewModel: ContentViewModelMaker {
    func contentViewModel(topic: S1Topic) -> ContentViewModel {
        return ContentViewModel(topic: topic)
    }
}

extension ContentViewModel {
    func reportComposeViewModel(floor: Floor) -> ReportComposeViewModel {
        return ReportComposeViewModel(
            topic: topic,
            floor: floor
        )
    }
}

extension ContentViewModel: QuoteFloorViewModelMaker {
    func quoteFloorViewModel(floors: [Floor], centerFloorID: Int) -> QuoteFloorViewModel {
        return QuoteFloorViewModel(
            topic: topic,
            floors: floors,
            centerFloorID: centerFloorID,
            baseURL: pageBaseURL()
        )
    }
}

extension ContentViewModel: UserViewModelMaker {
    func userViewModel(userID: Int) -> UserViewModel {
        let username = currentFloors.first(where: { $0.author.id == userID })?.author.name
        return UserViewModel(user: User(id: userID, name: username ?? ""))
    }
}

// MARK: - Misc
extension ContentViewModel {
    func saveTopicViewedState(lastViewedPosition: Double?) {

        S1LogInfo("[ContentVM] Save Topic View State Begin")

        if let lastViewedPosition = lastViewedPosition {
            topic.lastViewedPosition = NSNumber(value: lastViewedPosition)
        } else if topic.lastViewedPosition == nil || topic.lastViewedPage?.uintValue ?? 0 != currentPage.value {
            topic.lastViewedPosition = NSNumber(value: 0.0)
        }

        topic.lastViewedPage = NSNumber(value: currentPage.value)
        topic.lastViewedDate = Date()
        topic.lastReplyCount = topic.replyCount
        dataCenter.hasViewed(topic: topic)

        S1LogInfo("[ContentVM] Save Topic View State Finish")
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
