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

// swiftlint:disable nesting

final class TopicListViewModel: NSObject {
    let dataCenter: DataCenter

    struct Model: Equatable {
        enum Target: Equatable {
            case blank

            struct Forum: Equatable {
                let key: String
                let topics: [S1Topic]
            }
            case forum(Forum)

            struct Search: Equatable {
                let term: String
                let topics: [S1Topic]
            }
            case search(Search)
        }
        let target: Target

        enum State: Equatable {
            struct Loading: Equatable {
                enum Target: Equatable {
                    case forum(key: String)
                    case search(term: String)
                }
                let target: Target
                let showingHUD: Bool
            }
            case loading(Loading)
            case loaded
            case fetchingMore
            case allResultFetched
            case error(target: Loading.Target, message: String)
        }
        let state: State
    }

    enum Action {
        case pullToRefresh
        case tabTapped
        case loadMore
        case requestFinish
        case loadMoreFinish
        case reset
        case cloudKitUpdate
    }

    var activeRequestToken: Int = 0

    let model = MutableProperty(Model(target: .blank, state: .loaded))

    var stateTransitionBehaviors: [StateTransitionBehavior<TopicListViewModel, Model, Action>] = []

    let databaseConnection: YapDatabaseConnection = AppEnvironment.current.databaseManager.uiDatabaseConnection

    // Inputs
    let searchingTerm = MutableProperty("")
    let traitCollection = MutableProperty(UITraitCollection())
    let tableViewOffset = MutableProperty<CGPoint>(.zero)
    let refreshControlIsRefreshing = MutableProperty<Bool>(false)

    // Internal
    let cellTitleAttributes = MutableProperty([NSAttributedStringKey: Any]())
    let paletteNotification = MutableProperty(())
    let databaseChangedNotification = MutableProperty([Notification]())

    var cachedContentOffset = [String: CGPoint]()
    var cachedLastRefreshTime = [String: Date]()

    lazy var forumKeyMap: [String: String] = {
        let path = Bundle.main.path(forResource: "ForumKeyMap", ofType: "plist")!
        let map = NSDictionary(contentsOfFile: path)!
        return map as! [String: String]
    }()

    // Output

    enum TableViewContentOffsetAction {
        case toTop
        case restore(CGPoint)
    }

    let tableViewOffsetAction: Signal<TableViewContentOffsetAction, NoError>
    private let tableViewOffsetActionObserver: Signal<TableViewContentOffsetAction, NoError>.Observer

    let tableViewReloading: Signal<(), NoError>
    private let tableViewReloadingObserver: Signal<(), NoError>.Observer

    let tableViewCellUpdate: Signal<[IndexPath], NoError>
    private let tableViewCellUpdateObserver: Signal<[IndexPath], NoError>.Observer

    enum HudAction {
        case loading
        case text(String)
        case hide(delay: Double)
    }

    let hudAction: Signal<HudAction, NoError>
    private let hudActionObserver: Signal<HudAction, NoError>.Observer

    let refreshControlEndRefreshing: Signal<(), NoError>
    private let refreshControlEndRefreshingObserver: Signal<(), NoError>.Observer

    let searchBarPlaceholderText = MutableProperty(NSLocalizedString("TopicListViewController.SearchBar_Hint", comment: "Search"))
    let isTableViewHidden = MutableProperty(true)
    let isRefreshControlHidden = MutableProperty(true)
    let isShowingFetchingMoreIndicator = MutableProperty(false)

    // MARK: -

    init(dataCenter: DataCenter) {
        self.dataCenter = dataCenter

        (self.tableViewOffsetAction, self.tableViewOffsetActionObserver) = Signal<TableViewContentOffsetAction, NoError>.pipe()
        (self.tableViewReloading, self.tableViewReloadingObserver) = Signal<(), NoError>.pipe()
        (self.tableViewCellUpdate, self.tableViewCellUpdateObserver) = Signal<[IndexPath], NoError>.pipe()
        (self.hudAction, self.hudActionObserver) = Signal<HudAction, NoError>.pipe()
        (self.refreshControlEndRefreshing, self.refreshControlEndRefreshingObserver) = Signal<(), NoError>.pipe()

        super.init()

        stateTransitionBehaviors = [
            TableViewUpdateBehavior(viewModel: self),
            RestorePositionBehavior(viewModel: self),
            DataFreshRecordingBehavior(viewModel: self),
            HudBehavior(viewModel: self)
        ]

        isTableViewHidden <~ model.map { (model) in
            switch model.target {
            case .blank:
                return true
            case .forum, .search:
                return false
            }
        }

        isRefreshControlHidden <~ model.map { (model) in
            switch model.target {
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

        isShowingFetchingMoreIndicator <~ model.map { (model) in
            switch (model.target, model.state) {
            case (.forum, .fetchingMore):
                return true
            default:
                return false
            }
        }

        model.producer.startWithValues { [weak self] (model) in
            guard let strongSelf = self else { return }

            switch (model.target, model.state) {
            case (.forum, .loaded),
                 (.forum, .allResultFetched):
                strongSelf.refreshControlEndRefreshingObserver.send(value: ())
                strongSelf.tableViewReloadingObserver.send(value: ())

            case (.forum(let forum), .fetchingMore):
                strongSelf.loadNextPage(key: forum.key)

            case (_, .loading(let loading)):
                switch loading.target {
                case .forum(let key):
                    strongSelf.topicList(for: key)
                case .search(let term):
                    fatalError("Search is not yet supported.")
                }

            case (.search, .loaded),
                 (.search, .allResultFetched):
                strongSelf.refreshControlEndRefreshingObserver.send(value: ())
                strongSelf.tableViewReloadingObserver.send(value: ())

            case (.search(let search), .fetchingMore):
                fatalError("Fetching more for search is not yet supported")

            case (.blank, .loaded):
                strongSelf.refreshControlEndRefreshingObserver.send(value: ())
                strongSelf.tableViewReloadingObserver.send(value: ())

            case (.blank, .error):
                strongSelf.refreshControlEndRefreshingObserver.send(value: ())
                strongSelf.tableViewReloadingObserver.send(value: ())

            case (_, .error):
                fatalError("`.error` state must appear with `.blank` target.")
            case (.blank, .fetchingMore):
                fatalError("Invalide combination .blank with .fetchingMore")
            case (.blank, .allResultFetched):
                fatalError("Invalide combination .blank with .allResultFetched")
            }
        }

        // Debug
        model.producer.startWithValues { (model) in
            S1LogDebug("state -> \(model.debugDescription)")
        }
    }
}

// MARK: - Input

extension TopicListViewModel {
    private func transitModel(to newModel: Model, with action: Action) {
        dispatchPrecondition(condition: .onQueue(.main))

        func execute() {
            let oldModel = model.value
            stateTransitionBehaviors.forEach { (behavior) in
                behavior.preTransition(action: action, from: oldModel, to: newModel)
            }

            model.value = newModel

            stateTransitionBehaviors.forEach { (behavior) in
                behavior.postTransition(action: action, from: oldModel, to: newModel)
            }
        }

        func skip() {
            S1LogWarn("Skipping state transition from \(self.model.value.debugDescription) to \(newModel.debugDescription)")
        }

        let result = stateTransitionBehaviors.reduce(.notApplicable) { (result, behavior) -> StateTransitionRuleResult in
            switch result {
            case .notApplicable:
                return behavior.checkTransition(action: action, from: self.model.value, to: newModel)
            case .allow:
                return .allow
            case .reject:
                return .reject
            }
        }

        switch result {
        case .allow:
            execute()
        case .reject, .notApplicable:
            skip()
        }
//        switch (self.model.value, new) {
//        case (.loaded, .loaded):
//            execute()
//        case let (.loaded(target), .loading(fromTarget, _)) where target == fromTarget:
//            execute()
//        case let (.loaded(fromTarget), .fetchingMore(toTarget)) where fromTarget == toTarget:
//            execute()
//        case let (.loading(fromTarget, _), .loading(newFromTarget, _)) where fromTarget == newFromTarget:
//            execute()
//        case let (.loading(_, toTarget), .loaded(newTarget)) where toTarget == newTarget:
//            execute()
//        case let (.loading(_, toTarget), .error(newTarget, _)) where toTarget == newTarget:
//            execute()
//        case let (.loading(_, toTarget), .allResultFetched(newTarget)) where toTarget == newTarget:
//            execute()
//        case let (.fetchingMore(target), .loaded(newTarget)) where target == newTarget:
//            execute()
//        case (.error, .loaded):
//            execute()
//        case (.error, .loading):
//            execute()
//        default:
//            skip()
//            execute()
//        }
    }

    func tabBarTapped(key: String) {
        func isTappingOnSameForumInARow() -> Bool {
            if case let .forum(forum) = model.value.target, forum.key == key {
                return true
            } else {
                return false
            }
        }

        if
            hasRecentlyAccessedForum(key: key),
            !isTappingOnSameForumInARow(),
            let topics = self.dataCenter.cachedTopics(for: forumKeyMap[key]!)
        {
            let processedTopics = topics.map { topicWithTracedDataForTopic($0) }
            let new = Model(
                target: .forum(.init(key: key, topics: processedTopics)),
                state: .loaded
            )
            transitModel(to: new, with: .tabTapped)
        } else {
            let new = Model(
                target: model.value.target,
                state: .loading(.init(target: .forum(key: key), showingHUD: true))
            )
            transitModel(to: new, with: .tabTapped)
        }
    }

    func pullToRefreshTriggered() {
        func toLoadingTarget(_ target: Model.Target) -> Model.State.Loading.Target {
            switch target {
            case .blank:
                fatalError(".blank should never trigger pull to refresh!")
            case .forum(let forum):
                return .forum(key: forum.key)
            case .search(let search):
                return .search(term: search.term)
            }
        }

        let new = Model(
            target: model.value.target,
            state: .loading(.init(target: toLoadingTarget(model.value.target), showingHUD: false))
        )
        transitModel(to: new, with: .pullToRefresh)
    }

    func willDiplayCell(at indexPath: IndexPath) {
        guard case let .forum(forum) = model.value.target else {
            return
        }

        guard indexPath.row == forum.topics.count - 15 else {
            return
        }

        guard model.value.state == .loaded else {
            return
        }

        S1LogDebug("Reach (almost) last topic, load more.")

        let new = Model(
            target: model.value.target,
            state: .fetchingMore
        )
        transitModel(to: new, with: .loadMore)
    }

    func topicList(for key: String) {
        guard let mappedKey = self.forumKeyMap[key] else {
            S1LogDebug("topicListForKey triggered but we can not found mapped key for \(key).")
            return
        }

        S1LogInfo("key: \(key)")
        dataCenter.topics(for: mappedKey) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case let .success(topicList):
                let processedList = topicList.map { strongSelf.topicWithTracedDataForTopic($0) }
                ensureMainThread {
                    let new = Model(
                        target: .forum(.init(key: key, topics: processedList)),
                        state: .loaded
                    )
                    strongSelf.transitModel(to: new, with: .requestFinish)
                }
            case let .failure(error):
                ensureMainThread {
                    let new = Model(
                        target: .blank,
                        state: .error(target: .forum(key: key), message: error.localizedDescription)
                    )
                    strongSelf.transitModel(to: new, with: .requestFinish)
                }
            }
        }
    }

    func loadNextPage(key: String) {
        guard let mappedKey = self.forumKeyMap[key] else {
            S1LogDebug("loadNextPage triggered but we can not found mapped key for \(key).")
            return
        }

        dataCenter.loadNextPage(for: mappedKey) { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case let .success(topicList):
                let processedList = topicList.map { strongSelf.topicWithTracedDataForTopic($0) }

                ensureMainThread {
                    let new = Model(
                        target: .forum(.init(key: key, topics: processedList)),
                        state: .loaded
                    )
                    strongSelf.transitModel(to: new, with: .loadMoreFinish)
                }
            case .failure:
                ensureMainThread {
                    let new = Model(
                        target: strongSelf.model.value.target,
                        state: .loaded
                    )
                    strongSelf.transitModel(to: new, with: .loadMoreFinish)
                }
            }
        }
    }

    func reset() {
        transitModel(to: Model(target: .blank, state: .loaded), with: .reset)
    }

    @objc func cancelRequests() {
        dataCenter.cancelRequest()
    }
}

// MARK: - View Model

extension TopicListViewModel {
    func numberOfSections() -> Int {
        switch model.value.target {
        case .blank:
            return 0
        case .forum, .search:
            return 1
        }
    }

    func numberOfItems(in section: Int) -> Int {
        switch model.value.target {
        case .blank:
            return 0
        case .forum(let forum):
            return forum.topics.count
        case .search(let search):
            return search.topics.count
        }
    }

    func cellViewModel(at indexPath: IndexPath) -> TopicListCellViewModel {
        let topic: S1Topic
        let isPinningTop: Bool
        let attributedTitle: NSAttributedString
        switch model.value.target {
        case .search(let search):
            topic = search.topics[indexPath.row]

            isPinningTop = false

            let title = (topic.title ?? "").replacingOccurrences(of: "\n", with: "")
            let mutableAttributedTitle = NSMutableAttributedString(string: title, attributes: cellTitleAttributes.value)
            let termRange = (title as NSString).range(of: searchingTerm.value, options: [.caseInsensitive, .widthInsensitive])
            mutableAttributedTitle.addAttributes([.foregroundColor: AppEnvironment.current.colorManager.colorForKey("topiclist.cell.title.highlight")], range: termRange)
            attributedTitle = mutableAttributedTitle
        case .forum(let forum):
            topic = forum.topics[indexPath.row]

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
        switch model.value.target {
        case .forum(let forum):
            // Topic list will automatically update its model once database change pushed. No more need for manually update topic model.
            topic = forum.topics[indexPath.row]
        case .search(let search):
            topic = search.topics[indexPath.row]
        case .blank:
            S1LogError("blank target should not reach this method.")
            fatalError("blank target should not reach this method.")
        }

        return ContentViewModel(topic: topic, dataCenter: dataCenter)
    }
}

// MARK: - Behavior

extension TopicListViewModel {
    final class RestorePositionBehavior: StateTransitionBehavior<TopicListViewModel, Model, Action> {
        override func preTransition(action: Action, from: Model, to: Model) {
            guard let viewModel = self.viewModel else { return }

            /// Whenever leaving a forum, save its tableView.contentOffset
            switch (from.target, to.target) {
            case (.forum(let forum), .forum(let newForum)) where forum.key != newForum.key:
                S1LogDebug("Saving offset \(viewModel.tableViewOffset.value) for \(forum.key)")
                viewModel.cachedContentOffset[forum.key] = mutate(viewModel.tableViewOffset.value) { (value: inout CGPoint) in
                    value.y = value.y < 0.0 ? 0.0 : value.y
                }

            case (.forum(let forum), .blank),
                 (.forum(let forum), .search):
                S1LogDebug("Saving offset \(viewModel.tableViewOffset.value) for \(forum.key)")
                viewModel.cachedContentOffset[forum.key] = mutate(viewModel.tableViewOffset.value) { (value: inout CGPoint) in
                    value.y = value.y < 0.0 ? 0.0 : value.y
                }

            default:
                break
            }
        }

        override func postTransition(action: Action, from: Model, to: Model) {
            guard let viewModel = self.viewModel else { return }

            switch (to.target, to.state, action) {
            case (.forum(let forum), .loaded, .tabTapped):
                if let cachedOffset = viewModel.cachedContentOffset[forum.key], viewModel.hasRecentlyAccessedForum(key: forum.key) {
                    viewModel.tableViewOffsetActionObserver.send(value: .restore(cachedOffset))
                } else {
                    viewModel.tableViewOffsetActionObserver.send(value: .toTop)
                }

            case (.forum, .loaded, .requestFinish),
                 (.search, .loaded, .requestFinish):
                viewModel.tableViewOffsetActionObserver.send(value: .toTop)

            default:
                break
            }
        }
    }

    final class DataFreshRecordingBehavior: StateTransitionBehavior<TopicListViewModel, Model, Action> {
        override func postTransition(action: Action, from: Model, to: Model) {
            guard let viewModel = self.viewModel else { return }

            switch (from.state, to.target, action) {
            case (.loading, .forum(let forum), .requestFinish):
                viewModel.cachedLastRefreshTime[forum.key] = Date()
            default:
                break
            }
        }
    }

    final class HudBehavior: StateTransitionBehavior<TopicListViewModel, Model, Action> {
        override func postTransition(action: Action, from: Model, to: Model) {
            guard let viewModel = self.viewModel else { return }

            switch (to.target, to.state) {
            case (_, .loaded), (_, .allResultFetched):
                viewModel.hudActionObserver.send(value: .hide(delay: 0.3))

            case (_, .loading(let loading)):
                switch loading.target {
                case .forum:
                    if !viewModel.refreshControlIsRefreshing.value {
                        viewModel.hudActionObserver.send(value: .loading)
                    }
                case .search:
                    viewModel.hudActionObserver.send(value: .loading)
                }

            case (_, .fetchingMore):
                break

            case (_, .error(_, let message)):
                viewModel.hudActionObserver.send(value: .text(message))
            }
        }
    }

    final class TableViewUpdateBehavior: StateTransitionBehavior<TopicListViewModel, Model, Action> {
        override func postTransition(action: Action, from: Model, to: Model) {
            guard let viewModel = self.viewModel else { return }

            switch (from.state, to.target, action) {
            case (.loading, .forum(let forum), .requestFinish):
                viewModel.cachedLastRefreshTime[forum.key] = Date()
            default:
                break
            }
        }
    }
}

// MARK: - Private

extension TopicListViewModel {
    private func hasRecentlyAccessedForum(key: String) -> Bool {
        if let lastRefreshDate = cachedLastRefreshTime[key], Date().timeIntervalSince(lastRefreshDate) < 20.0 {
            return true
        } else {
            return false
        }
    }

    private func topicWithTracedDataForTopic(_ topic: S1Topic) -> S1Topic {
        if let tracedTopic = dataCenter.traced(topicID: topic.topicID.intValue)?.copy() as? S1Topic {
            tracedTopic.update(topic)
            return tracedTopic
        } else {
            return topic
        }
    }
}

// MARK: CloudKit
extension TopicListViewModel {
    private func _handleDatabaseChanged(with notifications: [Notification]) {
        switch model.value.target {
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

        func update(topics: [S1Topic]) -> ([S1Topic], [IndexPath]) {
            var updatedModelIndexPaths = [IndexPath]()
            var updatedTopics = topics
            for (index, topic) in topics.enumerated() {
                let key = "\(topic.topicID)"
                if databaseConnection.hasChange(forKey: key, inCollection: Collection_Topics, in: notifications) {
                    let updatedTopic = topicWithTracedDataForTopic(topics[index])
                    updatedTopics.remove(at: index)
                    updatedTopics.insert(updatedTopic, at: index)
                    updatedModelIndexPaths.append(IndexPath(row: index, section: 0))
                }
            }

            return (updatedTopics, updatedModelIndexPaths)
        }

        switch model.value.target {
        case .forum(let forum):
            let (updatedTopics, indexPaths) = update(topics: forum.topics)
            if indexPaths.count > 0 {
                tableViewCellUpdateObserver.send(value: indexPaths)
                let new = Model(
                    target: .forum(.init(key: forum.key, topics: updatedTopics)),
                    state: model.value.state
                )
                transitModel(to: new, with: .cloudKitUpdate)
            }

        case .search(let search):
            let (updatedTopics, indexPaths) = update(topics: search.topics)
            if indexPaths.count > 0 {
                tableViewCellUpdateObserver.send(value: indexPaths)
                let new = Model(
                    target: .search(.init(term: search.term, topics: updatedTopics)),
                    state: model.value.state
                )
                transitModel(to: new, with: .cloudKitUpdate)
            }
        case .blank:
            break
        }
    }
}

// MARK: - Extensions

extension TopicListViewModel.Model.State.Loading.Target: CustomDebugStringConvertible {
    var isForum: Bool {
        if case .forum = self {
            return true
        } else {
            return false
        }
    }

    var debugDescription: String {
        switch self {
        case .forum(let key):
            return "Forum \(key)"
        case .search(let term):
            return "Search \(term)"
        }
    }
}

extension TopicListViewModel.Model: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[\(target.debugDescription), \(state.debugDescription)]"
    }
}

extension TopicListViewModel.Model.Target: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .blank:
            return ".blank"
        case .forum(let forum):
            return ".forum \(forum.key)(\(forum.topics.count))"
        case .search(let search):
            return ".search \(search.term)(\(search.topics.count))"
        }
    }
}

extension TopicListViewModel.Model.State: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .loaded:
            return ".loaded"
        case .allResultFetched:
            return ".allResultFetched"
        case .fetchingMore:
            return ".fetchingMore"
        case .loading(let loading):
            return ".loading \(loading.target) hud: \(loading.showingHUD)"
        case .error(let target, let message):
            return ".error \(target) \(message)"
        }
    }
}
