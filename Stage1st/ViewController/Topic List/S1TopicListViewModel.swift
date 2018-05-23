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

    public enum State: Equatable {
        case forum(key: String)
        case search
        case blank

        init(key: String) {
            switch key {
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
            case .search:
                return "Search"
            case .blank:
                return ""
            case let .forum(key):
                return key
            }
        }

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.blank, .blank):
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

    // Used by .forum .search state
    var topics = [S1Topic]()

    let databaseConnection: YapDatabaseConnection = AppEnvironment.current.databaseManager.uiDatabaseConnection

    // Inputs
    let searchingTerm = MutableProperty("")
    let traitCollection = MutableProperty(UITraitCollection())
    let segmentControlIndex = MutableProperty(0)

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

    var cachedContentOffset = [String: CGPoint]()
    var cachedLastRefreshTime = [String: Date]()

    // MARK: -

    init(dataCenter: DataCenter) {
        self.dataCenter = dataCenter

        (self.tableViewReloading, self.tableViewReloadingObserver) = Signal<(), NoError>.pipe()
        (self.tableViewCellUpdate, self.tableViewCellUpdateObserver) = Signal<[IndexPath], NoError>.pipe()

        super.init()

        isTableViewHidden <~ currentState.map { $0 == .blank }
        isRefreshControlHidden <~ currentState.map { !$0.isForum }

        databaseChangedNotification <~ NotificationCenter.default.reactive
            .notifications(forName: .UIDatabaseConnectionDidUpdate)
            .map { (notification) in return notification.userInfo![kNotificationsKey] as! [Notification] }

        databaseChangedNotification.signal.observeValues { [weak self] (notifications) in
            S1LogVerbose("database connection did update.")
            guard let strongSelf = self else { return }
            strongSelf._handleDatabaseChanged(with: notifications)
        }

        searchBarPlaceholderText <~ MutableProperty
            .combineLatest(currentState, databaseChangedNotification)
            .producer.map { (state, _) -> String in
                switch state {
                case .search, .forum, .blank:
                    return NSLocalizedString("TopicListViewController.SearchBar_Hint", comment: "Search")
                }
            }.skipRepeats()

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

        // Debug
        currentState.producer.startWithValues { (state) in
            S1LogDebug("state -> \(state.stringRepresentation())")
        }
    }

    // MARK: Input
    func transitState(to newState: State) {
        self.currentState.value = newState
    }

    func tabbarTapped(key: String) {
    }

    func pullToRefreshTriggered() {

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

    func reset() {
        self.topics = [S1Topic]()
        self.currentState.value = .blank
    }

    @objc func cancelRequests() {
        dataCenter.cancelRequest()
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
        case .search:
            topic = topics[indexPath.row]

            isPinningTop = false

            let title = (topic.title ?? "").replacingOccurrences(of: "\n", with: "")
            let mutableAttributedTitle = NSMutableAttributedString(string: title, attributes: cellTitleAttributes.value)
            let termRange = (title as NSString).range(of: searchingTerm.value, options: [.caseInsensitive, .widthInsensitive])
            mutableAttributedTitle.addAttributes([.foregroundColor: ColorManager.shared.colorForKey("topiclist.cell.title.highlight")], range: termRange)
            attributedTitle = mutableAttributedTitle
        case .forum:
            topic = topics[indexPath.row]

            let title = (topic.title ?? "").replacingOccurrences(of: "\n", with: "")
            let lastReplyDate = topic.lastReplyDate ?? Date.distantPast
            isPinningTop = lastReplyDate.timeIntervalSinceNow > 0.0

            attributedTitle = NSAttributedString(string: title, attributes: cellTitleAttributes.value)
        case .blank:
            S1LogError("blank state should not reach this method.")
            fatalError("blank state should not reach this method.")
        }

        return TopicListCellViewModel(topic: topic, isPinningTop: isPinningTop, attributedTitle: attributedTitle)
    }

    func contentViewModel(at indexPath: IndexPath) -> ContentViewModel {
        let topic: S1Topic
        switch currentState.value {
        case .forum, .search:
            topic = topicWithTracedDataForTopic(topics[indexPath.row])
            topics.remove(at: indexPath.row)
            topics.insert(topic, at: indexPath.row)
        case .blank:
            S1LogError("blank state should not reach this method.")
            fatalError("blank state should not reach this method.")
        }

        return ContentViewModel(topic: topic, dataCenter: dataCenter)
    }
}

// MARK: YapDatabase
extension S1TopicListViewModel {
    private func _handleDatabaseChanged(with notifications: [Notification]) {
        switch currentState.value {
        case .forum, .search:
            // Dispatch heavy task to improve animation when dismissing content view controller.
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf._updateForumOrSearchList(with: notifications)
            }
        case .blank:
            break
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

extension S1TopicListViewModel.State {
    var isForumOrSearch: Bool {
        switch self {
        case .forum, .search:
            return true
        default:
            return false
        }
    }

    var isForum: Bool {
        switch self {
        case .forum:
            return true
        default:
            return false
        }
    }
}
