//
//  S1TopicListViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 5/19/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack
import YapDatabase.YapDatabaseSearchResultsView
import Alamofire
import ReactiveSwift
import Result

@objcMembers
final class S1TopicListViewModel: NSObject {
    let dataCenter: DataCenter

    let databaseConnection: YapDatabaseConnection = MyDatabaseManager.uiDatabaseConnection
    var viewMappings: YapDatabaseViewMappings?
    let searchQueue = YapDatabaseSearchQueue()

    public enum State: Equatable {
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

        func isArchiveTypes() -> Bool {
            return self == .history || self == .favorite
        }

        func isForumOrSearch() -> Bool {
            switch self {
            case .forum, .search:
                return true
            default:
                return false
            }
        }

        func isForum() -> Bool {
            switch self {
            case .forum:
                return true
            default:
                return false
            }
        }

        public static func == (lhs: State, rhs: State) -> Bool {
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
    let currentState = MutableProperty(State.blank)
    var currentKey: String {
        get {
            return currentState.value.stringRepresentation()
        }
        set {
            currentState.value = State(key: newValue)
        }
    }

    var topics = [S1Topic]()

    // Inputs
    let searchingTerm = MutableProperty("")
    let traitCollection = MutableProperty(UITraitCollection())

    // Internal
    let cellTitleAttributes = MutableProperty([NSAttributedStringKey: Any]())
    let paletteNotification = MutableProperty(())
    let databaseChangedNotification = MutableProperty([Notification]())

    // Output
    let tableViewReloading: Signal<(), NoError>
    private let tableViewReloadingObserver: Signal<(), NoError>.Observer

    let tableViewCellUpdate: Signal<[IndexPath], NoError>
    private let tableViewCellUpdateObserver: Signal<[IndexPath], NoError>.Observer

    let searchBarPlaceholderText = MutableProperty("")
    let isTableViewHidden = MutableProperty(true)
    let isRefreshControlHidden = MutableProperty(true)

    // MARK: -

    init(dataCenter: DataCenter) {
        self.dataCenter = dataCenter

        (self.tableViewReloading, self.tableViewReloadingObserver) = Signal<(), NoError>.pipe()
        (self.tableViewCellUpdate, self.tableViewCellUpdateObserver) = Signal<[IndexPath], NoError>.pipe()

        super.init()

        isTableViewHidden <~ currentState.producer.map { (state) -> Bool in
            return state == .blank
        }

        isRefreshControlHidden <~ currentState.producer.map { (state) -> Bool in
            return !state.isForum()
        }

        databaseChangedNotification <~ NotificationCenter.default.reactive
            .notifications(forName: .UIDatabaseConnectionDidUpdate)
            .map { (notification) in return notification.userInfo![kNotificationsKey] as! [Notification] }

        databaseChangedNotification.signal.observeValues { [weak self] (notifications) in
            DDLogVerbose("[TopicListVC] database connection did update.")
            guard let strongSelf = self else { return }
            strongSelf._handleDatabaseChanged(with: notifications)
        }

        searchBarPlaceholderText <~ MutableProperty
            .combineLatest(currentState, databaseChangedNotification)
            .producer.map { (state, _) -> String in
                switch state {
                case .favorite:
                    let count = dataCenter.numberOfFavorite()
                    return String(
                        format: NSLocalizedString("TopicListViewController.SearchBar_Detail_Hint", comment: "Search"),
                        NSNumber(value: count)
                    )
                case .history:
                    let count = dataCenter.numberOfTopics()
                    return String(
                        format: NSLocalizedString("TopicListViewController.SearchBar_Detail_Hint", comment: "Search"),
                        NSNumber(value: count)
                    )
                case .search, .forum:
                    return NSLocalizedString("TopicListViewController.SearchBar_Hint", comment: "Search")
                case .blank:
                    return NSLocalizedString("TopicListViewController.SearchBar_Hint", comment: "Search")
                }
            }.skipRepeats()

        MutableProperty.combineLatest(searchingTerm, currentState)
            .producer.skipRepeats({ (current, previous) -> Bool in
                func group(_ state: State) -> Int {
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
                    strongSelf._updateFilter(term)
                default:
                    break
                    // Nothing to do.
            }
        }

        paletteNotification <~ NotificationCenter.default.reactive
            .notifications(forName: .APPaletteDidChange)
            .map { _ in return () }

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

        cellTitleAttributes.signal.observeValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.tableViewReloadingObserver.send(value: ())
        }

//            .producer.startWithValues { (state, term, trait) in

//        }

        initializeMappings()
    }

    // MARK: Input

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

    func reset() {
        self.topics = [S1Topic]()
        self.currentState.value = .blank
    }

    @objc func cancelRequests() {
        dataCenter.cancelRequest()
    }

    // MARK: Output

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
}

// MARK: Private

extension S1TopicListViewModel {
    private func topicWithTracedDataForTopic(_ topic: S1Topic) -> S1Topic {
        if let tracedTopic = dataCenter.traced(topicID: topic.topicID.intValue)?.copy() as? S1Topic {
            tracedTopic.update(topic)
            return tracedTopic
        } else {
            return topic
        }
    }
}

// MARK: View Model

extension S1TopicListViewModel {
    func cellViewModel(at indexPath: IndexPath) -> TopicListCellViewModel {
        let topic: S1Topic
        let isPinningTop: Bool
        let attributedTitle: NSAttributedString
        switch currentState.value {
        case .favorite, .history:
            topic = topicAtIndexPath(indexPath)!

            isPinningTop = false

            let title = (topic.title ?? "").replacingOccurrences(of: "\n", with: "")
            let mutableAttributedTitle = NSMutableAttributedString(string: title, attributes: cellTitleAttributes.value)
            let termRange = (title as NSString).range(of: searchingTerm.value, options: [.caseInsensitive, .widthInsensitive])
            mutableAttributedTitle.addAttributes([
                .foregroundColor: ColorManager.shared.colorForKey("topiclist.cell.title.highlight")
            ], range: termRange)
            attributedTitle = mutableAttributedTitle
        case .search:
            topic = topics[indexPath.row]

            isPinningTop = false

            let title = (topic.title ?? "").replacingOccurrences(of: "\n", with: "")
            let mutableAttributedTitle = NSMutableAttributedString(string: title, attributes: cellTitleAttributes.value)
            let termRange = (title as NSString).range(of: searchingTerm.value, options: [.caseInsensitive, .widthInsensitive])
            mutableAttributedTitle.addAttributes([
                .foregroundColor: ColorManager.shared.colorForKey("topiclist.cell.title.highlight")
            ], range: termRange)
            attributedTitle = mutableAttributedTitle
        case .forum:
            topic = topics[indexPath.row]

            let title = (topic.title ?? "").replacingOccurrences(of: "\n", with: "")
            let lastReplyDate = topic.lastReplyDate ?? Date.distantPast
            isPinningTop = lastReplyDate.timeIntervalSinceNow > 0.0

            attributedTitle = NSAttributedString(string: title, attributes: cellTitleAttributes.value)
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
            guard transaction.ext(Ext_FullTextSearch_Archive) != nil else {
                // The view isn't ready yet.
                // We'll try again when we get a databaseConnectionDidUpdate notification.
                return
            }

            let groupFilterBlock: YapDatabaseViewMappingGroupFilter = { (_, _) in
                return true
            }
            let sortBlock: YapDatabaseViewMappingGroupSort = { (group1, group2, _) -> ComparisonResult in
                return S1Formatter.sharedInstance().compareDateString(group1, withDateString: group2)
            }

            self.viewMappings = YapDatabaseViewMappings(
                groupFilterBlock: groupFilterBlock,
                sortBlock: sortBlock,
                view: Ext_searchResultView_Archive
            )

            self.viewMappings?.update(with: transaction)
        }
    }

    func updateMappings() {
        databaseConnection.read { transaction in
            self.viewMappings?.update(with: transaction)
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

    private func _updateFilter(_ searchText: String) {
        let favoriteMark = currentState.value == .favorite ? "FY" : "F*"
        let query = "favorite:\(favoriteMark) title:\(searchText)*"
        DDLogDebug("[TopicListVM] Update filter: \(query)")
        searchQueue.enqueueQuery(query)
        MyDatabaseManager.bgDatabaseConnection.asyncReadWrite { transaction in
            if let ext = transaction.ext(Ext_searchResultView_Archive) as? YapDatabaseSearchResultsViewTransaction {
                ext.performSearch(with: self.searchQueue)
            }
        }
    }

    private func _handleDatabaseChanged(with notifications: [Notification]) {
        guard viewMappings != nil else {
            initializeMappings()
            return
        }

        updateMappings()

        if currentState.value.isArchiveTypes() {
            tableViewReloadingObserver.send(value: ())
        } else if currentState.value.isForumOrSearch() {
            // Dispatch heavy task to improve animations when dismissing content view controller.
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf._updateForumOrSearchList(with: notifications)
            }
        }
    }

    private func _updateForumOrSearchList(with notifications: [Notification]) {
        var updatedModelIndexPaths = [IndexPath]()
        for (index, topic) in topics.enumerated() {
            let key = "\(topic.topicID)"
            if databaseConnection.hasChange(forKey: key, inCollection: Collection_Topics, in: notifications) {
                let updatedTopic = topicWithTracedDataForTopic(topics[index])
                topics.remove(at: index)
                topics.insert(updatedTopic, at: index)
                updatedModelIndexPaths.append(IndexPath(row: index, section: 0))
            }
        }

        if updatedModelIndexPaths.count > 0 {
            tableViewCellUpdateObserver.send(value: updatedModelIndexPaths)
        }
    }
}
