//
//  TopicListViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 5/19/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Ainoaibo
import Foundation
import YapDatabase
import Alamofire
import ReactiveSwift
import Result

final class TopicListViewModel: NSObject {
    let dataCenter: DataCenter

    enum Target: Equatable {
        case blank
        case forum(key: String)
        case search(term: String)
    }

    enum State {
        case loading(from: Target, to: Target)
        case loaded(Target)
        case fetchingMore(Target)
        case allResultFetched(Target)
        case error(Target, Error)
    }

    let currentState = MutableProperty(State.loaded(.blank))

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

    enum HudAction {
        case loading
        case text(String)
        case hide
    }

    let hudAction: Signal<HudAction, NoError>
    private let hudActionObserver: Signal<HudAction, NoError>.Observer

    let searchBarPlaceholderText = MutableProperty(NSLocalizedString("TopicListViewController.SearchBar_Hint", comment: "Search"))
    let isTableViewHidden = MutableProperty(true)
    let isRefreshControlHidden = MutableProperty(true)

    var cachedContentOffset = [String: CGPoint]()
    var cachedLastRefreshTime = [String: Date]()

    lazy var forumKeyMap: [String: String] = {
        let path = Bundle.main.path(forResource: "ForumKeyMap", ofType: "plist")!
        let map = NSDictionary(contentsOfFile: path)!
        return map as! [String: String]
    }()

    // MARK: -

    init(dataCenter: DataCenter) {
        self.dataCenter = dataCenter

        (self.tableViewReloading, self.tableViewReloadingObserver) = Signal<(), NoError>.pipe()
        (self.tableViewCellUpdate, self.tableViewCellUpdateObserver) = Signal<[IndexPath], NoError>.pipe()
        (self.hudAction, self.hudActionObserver) = Signal<HudAction, NoError>.pipe()

        super.init()

        isTableViewHidden <~ currentState.map { (state) in
            switch state.currentTarget {
            case .blank:
                return true
            default:
                return false
            }
        }

        isRefreshControlHidden <~ currentState.map { (state) in
            switch state.currentTarget {
            case .blank, .search:
                return true
            case .forum:
                return false
            }
        }

        databaseChangedNotification <~ NotificationCenter.default.reactive
            .notifications(forName: .UIDatabaseConnectionDidUpdate)
            .map { (notification) in return notification.userInfo![kNotificationsKey] as! [Notification] }

        databaseChangedNotification.signal.observeValues { [weak self] (notifications) in
            S1LogVerbose("database connection did update.")
            guard let strongSelf = self else { return }
            strongSelf._handleDatabaseChanged(with: notifications)
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
                .foregroundColor: AppEnvironment.current.colorManager.colorForKey("topiclist.cell.title.text"),
                .paragraphStyle: paragraphStype
            ]
        }

        cellTitleAttributes.signal.observeValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.tableViewReloadingObserver.send(value: ())
        }

//            .producer.startWithValues { (state, term, trait) in

//        }

        currentState.producer
            .start(on: QueueScheduler.main)
            .observe(on: QueueScheduler.main)
            .startWithValues { [weak self] (state) in

                guard let strongSelf = self else { return }

                switch state {
                case let .loaded(target), let .allResultFetched(target):
                    strongSelf.hudActionObserver.send(value: .hide)
                    if target != .blank {
                        strongSelf.tableViewReloadingObserver.send(value: ())
                    }
                case let .loading(fromTarget, toTarget):
                    switch toTarget {
                    case let .forum(key):
                        strongSelf.hudActionObserver.send(value: .loading)
                        func shouldRefresh() -> Bool {
                            if fromTarget == toTarget {
                                return true
                            } else if let lastRefreshDate = strongSelf.cachedLastRefreshTime[key], Date().timeIntervalSince(lastRefreshDate) < 20.0 {
                                return false
                            } else {
                                return true
                            }
                        }

                        strongSelf.topicList(for: key, refresh: shouldRefresh())
                    case let .search(term):
                        strongSelf.hudActionObserver.send(value: .loading)
                        break
                    case .blank:
                        break
                    }
                case .fetchingMore:
                    strongSelf.loadNextPage()
                case let .error(target, error):
                    strongSelf.hudActionObserver.send(value: .text(error.localizedDescription))
                default:
                    break
                }
        }

        // Debug
        currentState.producer.startWithValues { (state) in
            S1LogDebug("state -> \(state.debugPrint())")
        }
    }

    // MARK: Input
    func transitState(to newState: State, with topics: [S1Topic]? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))

        func execute() {
            if let topics = topics {
                self.topics = topics
            }
            self.currentState.value = newState
        }

        func skip() {
            S1LogWarn("Skipping state transition from \(self.currentState.value.debugPrint()) to \(newState.debugPrint())")
        }

        switch (self.currentState.value, newState) {
        case let (.loaded(target), .loading(fromTarget, _)) where target == fromTarget:
            execute()
        case let (.loaded(fromTarget), .fetchingMore(toTarget)) where fromTarget == toTarget:
            execute()
        case let (.loading(fromTarget, toTarget), .loaded(newTarget)) where fromTarget == newTarget || toTarget == newTarget:
            execute()
        case let (.loading(fromTarget, toTarget), .error(newTarget, _)) where toTarget == newTarget:
            execute()
        case let (.loading(_, toTarget), .allResultFetched(newTarget)) where toTarget == newTarget:
            execute()
        case let (.fetchingMore(target), .loaded(newTarget)) where target == newTarget:
            execute()
        case let (.error, .loaded):
            execute()
        case let (.error, .loading):
            execute()
        default:
            skip()
        }
    }

    func tabBarTapped(key: String) {
        transitState(to: .loading(from: currentState.value.currentTarget, to: .forum(key: key)))
    }

    func pullToRefreshTriggered() {
        transitState(to: .loading(from: currentState.value.currentTarget, to: currentState.value.currentTarget))
    }

    func fetchingMoreTriggered() {
        transitState(to: .fetchingMore(currentState.value.currentTarget))
    }

    func topicList(for key: String, refresh: Bool) {
        guard let mappedKey = self.forumKeyMap[key] else {
            S1LogDebug("topicListForKey triggered but we can not found mapped key for \(key).")
            return
        }

        dataCenter.topics(for: mappedKey, shouldRefresh: refresh) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case let .success(topicList):
                let processedList = topicList.map { strongSelf.topicWithTracedDataForTopic($0) }
                ensureMainThread {
                    strongSelf.transitState(to: .loaded(.forum(key: key)), with: processedList)
                }
            case let .failure(error):
                ensureMainThread {
                    strongSelf.transitState(to: .error(.forum(key: key), error), with: [])
                }
            }
        }
    }

    func loadNextPage() {
        guard case let .fetchingMore(target) = currentState.value else {
            S1LogDebug("loadNextPage triggered but we are in the wrong state.")
            return
        }

        guard case let .forum(key) = target else {
            S1LogDebug("loadNextPage triggered but we are only load next page for forum target.")
            return
        }

        guard let mappedKey = self.forumKeyMap[key] else {
            S1LogDebug("loadNextPage triggered but we can not found mapped key for \(key).")
            return
        }

        dataCenter.loadNextPage(for: mappedKey) { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case let .success(topicList):
                let processedList = topicList.map { strongSelf.topicWithTracedDataForTopic($0) }

                ensureMainThread({
                    strongSelf.transitState(to: .loaded(.forum(key: key)), with: processedList)
                })
            case .failure:
                ensureMainThread({
                    strongSelf.transitState(to: .loaded(.forum(key: key)))
                })
            }
        }
    }

    func reset() {
        self.topics = [S1Topic]()
        self.currentState.value = .loaded(.blank)
    }

    @objc func cancelRequests() {
        dataCenter.cancelRequest()
    }
}

// MARK: Private

extension TopicListViewModel {
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

extension TopicListViewModel {
    func numberOfSections() -> Int {
        switch currentState.value.currentTarget {
        case .blank:
            return 0
        case .forum, .search:
            return 1
        }
    }

    func numberOfItems(in section: Int) -> Int {
        return self.topics.count
    }

    func cellViewModel(at indexPath: IndexPath) -> TopicListCellViewModel {
        let topic: S1Topic
        let isPinningTop: Bool
        let attributedTitle: NSAttributedString
        switch currentState.value.currentTarget {
        case .search:
            topic = topics[indexPath.row]

            isPinningTop = false

            let title = (topic.title ?? "").replacingOccurrences(of: "\n", with: "")
            let mutableAttributedTitle = NSMutableAttributedString(string: title, attributes: cellTitleAttributes.value)
            let termRange = (title as NSString).range(of: searchingTerm.value, options: [.caseInsensitive, .widthInsensitive])
            mutableAttributedTitle.addAttributes([.foregroundColor: AppEnvironment.current.colorManager.colorForKey("topiclist.cell.title.highlight")], range: termRange)
            attributedTitle = mutableAttributedTitle
        case .forum:
            topic = topics[indexPath.row]

            let title = (topic.title ?? "").replacingOccurrences(of: "\n", with: "")
            let lastReplyDate = topic.lastReplyDate ?? Date.distantPast
            isPinningTop = lastReplyDate.timeIntervalSinceNow > 0.0

            attributedTitle = NSAttributedString(string: title, attributes: cellTitleAttributes.value)
        case .blank:
            S1LogError("blank target should not reach this method.")
            fatalError("blank target should not reach this method.")
        }

        return TopicListCellViewModel(topic: topic, isPinningTop: isPinningTop, attributedTitle: attributedTitle)
    }

    func contentViewModel(at indexPath: IndexPath) -> ContentViewModel {
        let topic: S1Topic
        switch currentState.value.currentTarget {
        case .forum, .search:
            topic = topicWithTracedDataForTopic(topics[indexPath.row])
            topics.remove(at: indexPath.row)
            topics.insert(topic, at: indexPath.row)
        case .blank:
            S1LogError("blank target should not reach this method.")
            fatalError("blank target should not reach this method.")
        }

        return ContentViewModel(topic: topic, dataCenter: dataCenter)
    }
}

// MARK: YapDatabase
extension TopicListViewModel {
    private func _handleDatabaseChanged(with notifications: [Notification]) {
        switch currentState.value.currentTarget {
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
        dispatchPrecondition(condition: .onQueue(.main))

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

// MARK: -

extension TopicListViewModel.Target: CustomStringConvertible {
    var isForum: Bool {
        if case .forum = self {
            return true
        } else {
            return false
        }
    }

    var description: String {
        switch self {
        case .blank:
            return "Blank"
        case .forum(let key):
            return "Forum \(key)"
        case .search(let term):
            return "Search \(term)"
        }
    }
}

extension TopicListViewModel.State {
    var currentTarget: TopicListViewModel.Target {
        switch self {
        case .loading(from: let target, to: _),
             .loaded(let target),
             .fetchingMore(let target),
             .allResultFetched(let target),
             .error(let target, _):
        return target
        }
    }

    func debugPrint() -> String {
        switch self {
        case let .loading(from: target, to: toTarget):
            return "S1TopicListViewModel.State.loading(\(target.description) -> \(toTarget.description))"
        case let .loaded(target):
            return "S1TopicListViewModel.State.loaded(\(target.description))"
        case let .fetchingMore(target):
            return "S1TopicListViewModel.State.fetchingMore(\(target.description))"
        case let .allResultFetched(target):
            return "S1TopicListViewModel.State.allResultFetched(\(target.description))"
        case let .error(target, error):
            return "S1TopicListViewModel.State.error(\(target.description) | \(String(dumping: error)))"
        }
    }
}
