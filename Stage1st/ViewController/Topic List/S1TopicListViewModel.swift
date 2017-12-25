//
//  S1TopicListViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 5/19/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack
import YapDatabase.YapDatabaseFullTextSearch
import YapDatabase.YapDatabaseSearchResultsView
import YapDatabase.YapDatabaseFilteredView
import Alamofire
import ReactiveSwift

// MARK: -

@objcMembers
final class S1TopicListViewModel: NSObject {
    let dataCenter: DataCenter
    var viewMappings: YapDatabaseViewMappings?
    let databaseConnection: YapDatabaseConnection = MyDatabaseManager.uiDatabaseConnection
    lazy var searchQueue = YapDatabaseSearchQueue()

    public enum ContentState: Equatable {
        case history, favorite
        case search
        case forum(key: String)
        case blank

        init(key: String) {
            switch key {
            case "History":
                self = .history
            case "Favorite":
                self = .favorite
            case "Search":
                self = .search
            case "":
                self = .blank
            default:
                self = .forum(key: key)
            }
        }

        func stringRepresentation() -> String {
            switch self {
            case .history:
                return "History"
            case .favorite:
                return "Favorite"
            case .search:
                return "Search"
            case .blank:
                return ""
            case let .forum(key):
                return key
            }
        }

        public static func == (lhs: ContentState, rhs: ContentState) -> Bool {
            switch (lhs, rhs) {
            case (.blank, .blank):
                return true
            case (.history, .history):
                return true
            case (.favorite, .favorite):
                return true
            case (.search, .search):
                return true

            case let (.forum(key1), .forum(key2)):
                return key1 == key2
            default:
                return false
            }
        }
    }
    let currentState = MutableProperty(ContentState.blank)
    var currentKey: String {
        get {
            return currentState.value.stringRepresentation()
        }
        set {
            currentState.value = ContentState(key: newValue)
        }
    }
    var topics = [S1Topic]()

    // Inputs
    let searchingTerm = MutableProperty("")
    let traitCollection = MutableProperty(UITraitCollection())

    // Internal
    let cellTitleAttributes = MutableProperty([NSAttributedStringKey: Any]())
    let paletteNotification = MutableProperty(())

    init(dataCenter: DataCenter) {
        self.dataCenter = dataCenter
        super.init()

        paletteNotification <~ NotificationCenter.default.reactive.notifications(forName: .APPaletteDidChange)
            .map { _ in return () }

        MutableProperty.combineLatest(searchingTerm, currentState)
            .producer.skipRepeats({ (current, previous) -> Bool in
                func group(_ state: ContentState) -> Int {
                    switch state {
                    case .history:
                        return 0
                    case .favorite:
                        return 1
                    default:
                        return 2
                    }
                }
                if group(current.1) == 2 && group(previous.1) == 2 {
                    return true
                } else {
                    return current.0 == previous.0 && group(current.1) == group(previous.1)
                }
            })
            .startWithValues { [weak self] (term, state) in
                guard let strongSelf = self else { return }

                switch state {
                case .history, .favorite:
                    strongSelf.updateFilter(term)
                default:
                    break
                    // Nothing to do.
            }
        }

        cellTitleAttributes <~ MutableProperty.combineLatest(traitCollection, paletteNotification).map { (trait, _) in
            let paragraphStype = NSMutableParagraphStyle()
            paragraphStype.lineBreakMode = .byWordWrapping
            paragraphStype.alignment = .left

            let font: UIFont
            switch trait.horizontalSizeClass {
            case .compact:
                font = UIFont.systemFont(ofSize: 15.0)
            default:
                font = UIFont.systemFont(ofSize: 17.0)
            }

            return [
                .font: font,
                .foregroundColor: ColorManager.shared.colorForKey("topiclist.cell.title.text"),
                .paragraphStyle: paragraphStype
            ]
        }

//            .producer.startWithValues { (state, term, trait) in

//        }

        initializeMappings()
    }

    func topicListForKey(_ key: String, refresh: Bool, success: @escaping (_ topicList: [S1Topic]) -> Void, failure: @escaping (_ error: Error) -> Void) {
        dataCenter.topics(for: key, shouldRefresh: refresh, successBlock: { [weak self] topicList in
            guard let strongSelf = self else { return }
            let processedList = topicList.map { strongSelf.topicWithTracedDataForTopic($0) }
            strongSelf.topics = processedList
            ensureMainThread({
                success(processedList)
            })
        }, failureBlock: { error in
            ensureMainThread({
                failure(error)
            })
        })
    }

    func loadNextPageForKey(_ key: String, completion: @escaping (Alamofire.Result<Void>) -> Void) {
        dataCenter.loadNextPage(for: key, successBlock: { [weak self] topicList in
            guard let strongSelf = self else { return }
            let processedList = topicList.map { strongSelf.topicWithTracedDataForTopic($0) }
            strongSelf.topics = processedList
            ensureMainThread({
                completion(.success(()))
            })
        }, failureBlock: { error in
            ensureMainThread({
                completion(.failure(error))
            })
        })
    }

    func numberOfSections() -> Int {
        if let result = viewMappings?.numberOfSections() {
            return Int(result)
        } else {
            return 1
        }
    }

    func numberOfItemsInSection(_ section: Int) -> Int {
        if let result = viewMappings?.numberOfItems(inSection: UInt(section)) {
            return Int(result)
        } else {
            return 0
        }
    }

    func unfavoriteTopicAtIndexPath(_ indexPath: IndexPath) {
        if let topic = topicAtIndexPath(indexPath) {
            dataCenter.removeTopicFromFavorite(topicID: topic.topicID.intValue)
        }
    }

    func deleteTopicAtIndexPath(_ indexPath: IndexPath) {
        if let topic = topicAtIndexPath(indexPath) {
            dataCenter.removeTopicFromHistory(topicID: topic.topicID.intValue)
        }
    }

    func topicWithTracedDataForTopic(_ topic: S1Topic) -> S1Topic {
        if let tracedTopic = dataCenter.traced(topicID: topic.topicID.intValue)?.copy() as? S1Topic {
            tracedTopic.update(topic)
            return tracedTopic
        } else {
            return topic
        }
    }

    func reset() {
        self.topics = [S1Topic]()
        self.currentState.value = .blank
    }

    @objc func cancelRequests() {
        dataCenter.cancelRequest()
    }
}

extension S1TopicListViewModel {
    func cellViewModel(at indexPath: IndexPath) -> TopicListCellViewModel {
        let topic: S1Topic
        let isPinningTop: Bool
        let attributedTitle: NSAttributedString
        switch currentState.value {
        case .favorite, .history:
            topic = topicAtIndexPath(indexPath)!

            isPinningTop = false

            let title = topic.title ?? ""
            let mutableAttributedTitle = NSMutableAttributedString(string: title, attributes: cellTitleAttributes.value)
            let termRange = (title as NSString).range(of: searchingTerm.value, options: [.caseInsensitive, .widthInsensitive])
            mutableAttributedTitle.addAttributes([
                .foregroundColor: ColorManager.shared.colorForKey("topiclist.cell.title.highlight")
            ], range: termRange)
            attributedTitle = mutableAttributedTitle
        case .search:
            topic = topics[indexPath.row]

            isPinningTop = false

            let title = topic.title ?? ""
            let mutableAttributedTitle = NSMutableAttributedString(string: title, attributes: cellTitleAttributes.value)
            let termRange = (title as NSString).range(of: searchingTerm.value, options: [.caseInsensitive, .widthInsensitive])
            mutableAttributedTitle.addAttributes([
                .foregroundColor: ColorManager.shared.colorForKey("topiclist.cell.title.highlight")
            ], range: termRange)
            attributedTitle = mutableAttributedTitle
        case .forum:
            topic = topics[indexPath.row]

            let lastReplyDate = topic.lastReplyDate ?? Date.distantPast
            isPinningTop = lastReplyDate.timeIntervalSinceNow > 0.0

            attributedTitle = NSAttributedString(string: topic.title ?? "", attributes: cellTitleAttributes.value)
        case .blank:
            DDLogError("blank state should not reach this method.")
            fatalError("blank state should not reach this method.")
        }

        return TopicListCellViewModel(topic: topic, isPinningTop: isPinningTop, attributedTitle: attributedTitle)
    }

    func contentViewModel(at indexPath: IndexPath) -> ContentViewModel {
        let topic: S1Topic
        switch currentState.value {
        case .favorite, .history:
            topic = topicAtIndexPath(indexPath)!
        case .forum, .search:
            topic = topicWithTracedDataForTopic(topics[indexPath.row])
            topics.remove(at: indexPath.row)
            topics.insert(topic, at: indexPath.row)
        default:
            fatalError()
        }

        return ContentViewModel(topic: topic, dataCenter: dataCenter)
    }
}

// MARK: YapDatabase
extension S1TopicListViewModel {
    func initializeMappings() {
        databaseConnection.read { transaction in
            if transaction.ext(Ext_FullTextSearch_Archive) != nil {
                self.viewMappings = YapDatabaseViewMappings(groupFilterBlock: { (_, _) -> Bool in
                    true
                }, sortBlock: { (group1, group2, _) -> ComparisonResult in
                    S1Formatter.sharedInstance().compareDateString(group1, withDateString: group2)
                }, view: Ext_searchResultView_Archive)
                self.viewMappings?.update(with: transaction)
            } else {
                // The view isn't ready yet.
                // We'll try again when we get a databaseConnectionDidUpdate notification.
            }
        }
    }

    func topicAtIndexPath(_ indexPath: IndexPath) -> S1Topic? {
        var topic: S1Topic? = nil
        databaseConnection.read { transaction in
            if let ext = transaction.ext(Ext_searchResultView_Archive) as? YapDatabaseViewTransaction, let viewMappings = self.viewMappings {
                topic = ext.object(at: indexPath, with: viewMappings) as? S1Topic
            }
        }
        return topic
    }

    private func updateFilter(_ searchText: String) {
        let favoriteMark = currentState.value == ContentState.favorite ? "FY" : "F*"
        let query = "favorite:\(favoriteMark) title:\(searchText)*"
        DDLogDebug("[TopicListVC] Update filter: \(query)")
        searchQueue.enqueueQuery(query)
        MyDatabaseManager.bgDatabaseConnection.asyncReadWrite { transaction in
            if let ext = transaction.ext(Ext_searchResultView_Archive) as? YapDatabaseSearchResultsViewTransaction {
                ext.performSearch(with: self.searchQueue)
            }
        }
    }

    func updateMappings() {
        databaseConnection.read { transaction in
            self.viewMappings?.update(with: transaction)
        }
    }

    func searchBarPlaceholderStringForCurrentKey(_ key: String) -> String {
        let count = key == "Favorite" ? dataCenter.numberOfFavorite() : dataCenter.numberOfTopics()
        return String(format: NSLocalizedString("TopicListViewController.SearchBar_Detail_Hint", comment: "Search"), NSNumber(value: count))
    }
}
