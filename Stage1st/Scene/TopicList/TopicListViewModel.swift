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

// swiftlint:disable nesting

final class TopicListViewModel: NSObject {
    var dataCenter: DataCenter { AppEnvironment.current.dataCenter }

    struct Model: Equatable {
        enum Target: Equatable {
            case blank

            struct Forum: Equatable {
                let key: String
                let topics: [S1Topic]
                let allResultFetched: Bool
            }
            case forum(Forum)

            struct Search: Equatable {
                let term: String
                let topics: [S1Topic]
                let searchID: String?
                let page: Int
                let allResultFetched: Bool
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
            case error(target: Loading.Target, message: String)
        }
        let state: State
    }

    enum Action: Equatable {
        case pullToRefresh
        case tabTapped
        case searchTapped
        case loadMore
        case requestFinish
        case loadMoreFinish
        case reset
        case cloudKitUpdate([IndexPath])
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
    let cellTitleAttributes = MutableProperty([NSAttributedString.Key: Any]())
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

    let tableViewOffsetAction: Signal<TableViewContentOffsetAction, Never>
    private let tableViewOffsetActionObserver: Signal<TableViewContentOffsetAction, Never>.Observer

    let tableViewReloading: Signal<(), Never>
    private let tableViewReloadingObserver: Signal<(), Never>.Observer

    let tableViewCellUpdate: Signal<[IndexPath], Never>
    private let tableViewCellUpdateObserver: Signal<[IndexPath], Never>.Observer

    enum HudAction {
        case loading
        case text(String)
        case hide(delay: Double)
    }

    let hudAction: Signal<HudAction, Never>
    private let hudActionObserver: Signal<HudAction, Never>.Observer

    let refreshControlEndRefreshing: Signal<(), Never>
    private let refreshControlEndRefreshingObserver: Signal<(), Never>.Observer

    let tabBarSelection: MutableProperty<S1TabBar.Selection> = MutableProperty(.none)

    let searchTextClearAction: Signal<(), Never>
    private let searchTextClearActionObserver: Signal<(), Never>.Observer

    let searchBarPlaceholderText = MutableProperty(NSLocalizedString("TopicListViewController.SearchBar_Hint", comment: "Search"))
    let isTableViewHidden = MutableProperty(true)
    let isRefreshControlHidden = MutableProperty(true)
    let isShowingFooterView = MutableProperty(false)
    let footerViewMessage = MutableProperty("")

    // MARK: -

    override init() {

        (self.tableViewOffsetAction, self.tableViewOffsetActionObserver) = Signal<TableViewContentOffsetAction, Never>.pipe()
        (self.tableViewReloading, self.tableViewReloadingObserver) = Signal<(), Never>.pipe()
        (self.tableViewCellUpdate, self.tableViewCellUpdateObserver) = Signal<[IndexPath], Never>.pipe()
        (self.hudAction, self.hudActionObserver) = Signal<HudAction, Never>.pipe()
        (self.refreshControlEndRefreshing, self.refreshControlEndRefreshingObserver) = Signal<(), Never>.pipe()
        (self.searchTextClearAction, self.searchTextClearActionObserver) = Signal<(), Never>.pipe()

        super.init()

        stateTransitionBehaviors = [
            TableViewUpdateBehavior(viewModel: self),
            RefreshControlBehavior(viewModel: self),
            RestorePositionBehavior(viewModel: self),
            RefreshTimeCachingBehavior(viewModel: self),
            HudBehavior(viewModel: self),
            TabSelectionBehavior(viewModel: self),
            SearchTextClearBehavior(viewModel: self)
        ]

        isTableViewHidden <~ model.map { (model) in
            switch model.target {
            case .blank:
                return true
            case .forum, .search:
                return false
            }
        }.skipRepeats()

        isRefreshControlHidden <~ model.map { (model) in
            switch model.target {
            case .blank, .search:
                return true
            case .forum:
                return false
            }
        }.skipRepeats()

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

        isShowingFooterView <~ model.map { (model) in
            switch (model.target, model.state) {
            case (_, .fetchingMore):
                return true
            case (.forum(let forum), _) where forum.allResultFetched == true:
                return true
            case (.search(let search), _) where search.allResultFetched == true:
                return true
            default:
                return false
            }
        }.skipRepeats()

        footerViewMessage <~ model.map { (model) in
            switch (model.target, model.state) {
            case (_, .fetchingMore):
                return NSLocalizedString("TopicListViewController.MessageFooterView.loading", comment: "loading")
            case (.forum(let forum), _) where forum.allResultFetched == true:
                return String(
                    format: NSLocalizedString("TopicListViewController.MessageFooterView.allTopics", comment: "allTopics"),
                    NSNumber(value: forum.topics.count)
                )
            case (.search(let search), _) where search.allResultFetched == true:
                return String(
                    format: NSLocalizedString("TopicListViewController.MessageFooterView.allSearchResults", comment: "allSearchResults"),
                    NSNumber(value: search.topics.count)
                )
            default:
                return ""
            }
        }.skipRepeats()

        model.producer.startWithValues { (model) in
            switch (model.target, model.state) {
            case (_, .loaded):
                break

            case (.blank, .error):
                break

            case (.forum, .fetchingMore):
                break

            case (_, .loading):
                break

            case (.search, .fetchingMore):
                break

            case (_, .error):
                S1FatalError("`.error` state must appear with `.blank` target.")

            case (.blank, .fetchingMore):
                S1FatalError("Invalide combination .blank with .fetchingMore")
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

        let oldModel = model.value
        stateTransitionBehaviors.forEach { (behavior) in
            behavior.preTransition(action: action, from: oldModel, to: newModel)
        }

        model.value = newModel

        // Note: Order matters, we should execute behavior in front first.
        stateTransitionBehaviors.forEach { (behavior) in
            behavior.postTransition(action: action, from: oldModel, to: newModel)
        }
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
                target: .forum(.init(key: key, topics: processedTopics, allResultFetched: false)),
                state: .loaded
            )
            transitModel(to: new, with: .tabTapped)
            _ = newToken()
        } else {
            let new = Model(
                target: model.value.target,
                state: .loading(.init(target: .forum(key: key), showingHUD: true))
            )
            transitModel(to: new, with: .tabTapped)
            fetchTopicList(for: key)
        }
    }

    func searchButtonTapped(term: String) {
        let new = Model(
            target: model.value.target,
            state: .loading(.init(target: .search(term: term), showingHUD: true))
        )
        transitModel(to: new, with: .searchTapped)
        self.search(for: term)
    }

    func pullToRefreshTriggered() {
        switch model.value.target {
        case .forum(let forum):
            let new = Model(
                target: .forum(forum),
                state: .loading(.init(target: .forum(key: forum.key), showingHUD: true))
            )
            transitModel(to: new, with: .pullToRefresh)
            fetchTopicList(for: forum.key)

        case .search(let search):
            let new = Model(
                target: .search(search),
                state: .loading(.init(target: .search(term: search.term), showingHUD: true))
            )
            transitModel(to: new, with: .pullToRefresh)
            self.search(for: search.term)

        case .blank:
            S1FatalError(".blank should never trigger pull to refresh!")
        }
    }

    func willDisplayCell(at indexPath: IndexPath) {
        // Loading More should not be able to interrupt other operations.
        guard model.value.state == .loaded else {
            return
        }

        switch model.value.target {
        case .forum(let forum):
            guard indexPath.row == forum.topics.count - 15 else {
                return
            }

            guard !forum.allResultFetched else {
                return
            }

            S1LogDebug("Reach (almost) last topic, load more.")

            let new = Model(
                target: model.value.target,
                state: .fetchingMore
            )
            transitModel(to: new, with: .loadMore)
            loadNextPage(key: forum.key)

        case .search(let search):
            guard indexPath.row == search.topics.count - 5 else {
                return
            }

            guard !search.allResultFetched else {
                return
            }

            S1LogDebug("Reach (almost) last topic, load more.")

            let new = Model(
                target: model.value.target,
                state: .fetchingMore
            )
            transitModel(to: new, with: .loadMore)
            loadNextSearchPage(for: search.searchID!, page: search.page + 1)

        case .blank:
            S1FatalError(".blank should never trigger loading more action!")
        }
    }

    func reset() {
        _ = newToken()
        transitModel(to: Model(target: .blank, state: .loaded), with: .reset)
    }

    private func fetchTopicList(for key: String) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let mappedKey = self.forumKeyMap[key] else {
            S1LogDebug("topicListForKey triggered but we can not found mapped key for \(key).")
            return
        }

        let token = newToken()

        dataCenter.topics(for: mappedKey) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case let .success(topicList):
                let processedList = topicList.map { strongSelf.topicWithTracedDataForTopic($0) }
                ensureMainThread {
                    guard strongSelf.activeRequestToken == token else {
                        S1LogWarn("Skipping topicList(for: \(key)) success because token(\(token)) != activeRequestToken(\(strongSelf.activeRequestToken))")
                        return
                    }

                    // TODO: Add all result fetched check.
                    let new = Model(
                        target: .forum(.init(key: key, topics: processedList, allResultFetched: false)),
                        state: .loaded
                    )
                    strongSelf.transitModel(to: new, with: .requestFinish)
                }
            case let .failure(error):
                ensureMainThread {
                    guard strongSelf.activeRequestToken == token else {
                        S1LogWarn("Skipping topicList(for: \(key)) failure because token(\(token)) != activeRequestToken(\(strongSelf.activeRequestToken))")
                        return
                    }

                    if let urlError = error as? URLError, urlError.code == .cancelled {
                        let new = Model(
                            target: strongSelf.model.value.target,
                            state: .loaded
                        )
                        strongSelf.transitModel(to: new, with: .requestFinish)

                        return
                    }

                    if case AFError.responseSerializationFailed(.decodingFailed(let decodingError)) = error {
                        AppEnvironment.current.eventTracker.recordError(decodingError, withAdditionalUserInfo: ["S1Context": "Fetch Topic List"])
                    } else if let urlError = error as? URLError, urlError.code == .httpTooManyRedirects {
                        URLCache.shared.removeAllCachedResponses()
                        AppEnvironment.current.eventTracker.recordError(urlError, withAdditionalUserInfo: [
                            "S1Context": "Fetch Topic List"
                        ])
                    }

                    let new = Model(
                        target: .blank,
                        state: .error(target: .forum(key: key), message: error.localizedDescription)
                    )
                    strongSelf.transitModel(to: new, with: .requestFinish)
                }
            }
        }
    }

    private func loadNextPage(key: String) {
        guard let mappedKey = self.forumKeyMap[key] else {
            S1LogDebug("loadNextPage triggered but we can not found mapped key for \(key).")
            return
        }

        let token = newToken()

        dataCenter.loadNextPage(for: mappedKey) { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case let .success(topicList):
                let processedList = topicList.map { strongSelf.topicWithTracedDataForTopic($0) }

                ensureMainThread {
                    guard strongSelf.activeRequestToken == token else {
                        S1LogWarn("Skipping loadNextPage(for: \(key)) success because token(\(token)) != activeRequestToken(\(strongSelf.activeRequestToken))")
                        return
                    }

                    // TODO: Add all result fetched check.
                    let new = Model(
                        target: .forum(.init(key: key, topics: processedList, allResultFetched: false)),
                        state: .loaded
                    )
                    strongSelf.transitModel(to: new, with: .loadMoreFinish)
                }
            case .failure:
                ensureMainThread {
                    guard strongSelf.activeRequestToken == token else {
                        S1LogWarn("Skipping loadNextPage(for: \(key)) success because token(\(token)) != activeRequestToken(\(strongSelf.activeRequestToken))")
                        return
                    }

                    let new = Model(
                        target: strongSelf.model.value.target,
                        state: .loaded
                    )
                    strongSelf.transitModel(to: new, with: .loadMoreFinish)
                }
            }
        }
    }

    private func search(for term: String) {
        let token = newToken()

        dataCenter.searchTopics(for: term) { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case .success((let topics, let searchID)):
                ensureMainThread {
                    guard strongSelf.activeRequestToken == token else {
                        S1LogWarn("Skipping search(for: \(term)) success because token(\(token)) != activeRequestToken(\(strongSelf.activeRequestToken))")
                        return
                    }

                    let new = Model(
                        target: .search(.init(term: term, topics: topics, searchID: searchID, page: 1, allResultFetched: searchID == nil)),
                        state: .loaded
                    )
                    strongSelf.transitModel(to: new, with: .requestFinish)
                }
            case .failure(let error):
                ensureMainThread {
                    guard strongSelf.activeRequestToken == token else {
                        S1LogWarn("Skipping search(for: \(term)) failure because token(\(token)) != activeRequestToken(\(strongSelf.activeRequestToken))")
                        return
                    }

                    if let urlError = error as? URLError, urlError.code == .cancelled {
                        let new = Model(
                            target: strongSelf.model.value.target,
                            state: .loaded
                        )
                        strongSelf.transitModel(to: new, with: .requestFinish)

                        return
                    }

                    let new = Model(
                        target: .blank,
                        state: .error(target: .search(term: term), message: error.localizedDescription)
                    )
                    strongSelf.transitModel(to: new, with: .requestFinish)
                }
            }
        }
    }

    private func loadNextSearchPage(for searchID: String, page: Int) {
        let token = newToken()

        dataCenter.nextSearchPage(for: searchID, page: page) { [weak self] (result) in
            guard let strongSelf = self else { return }

            switch result {
            case .success((let topics, let newSearchID)):
                ensureMainThread {
                    guard strongSelf.activeRequestToken == token else {
                        S1LogWarn("Skipping loadNextSearchPage(for: \(searchID), page: \(page)) success because token(\(token)) != activeRequestToken(\(strongSelf.activeRequestToken))")
                        return
                    }

                    guard case let .search(search) = strongSelf.model.value.target else {
                        return
                    }

                    let newTarget = Model.Target.search(.init(
                        term: search.term,
                        topics: search.topics + topics,
                        searchID: newSearchID,
                        page: search.page + 1,
                        allResultFetched: newSearchID == nil
                    ))

                    let new = Model(target: newTarget, state: .loaded)
                    strongSelf.transitModel(to: new, with: .loadMoreFinish)
                }
            case .failure:
                ensureMainThread {
                    guard strongSelf.activeRequestToken == token else {
                        S1LogWarn("Skipping loadNextSearchPage(for: \(searchID), page: \(page)) failure because token(\(token)) != activeRequestToken(\(strongSelf.activeRequestToken))")
                        return
                    }

                    let new = Model(
                        target: strongSelf.model.value.target,
                        state: .loaded
                    )
                    strongSelf.transitModel(to: new, with: .loadMoreFinish)
                }
            }
        }
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
            S1FatalError("blank target should not reach this method.")
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
            S1FatalError("blank target should not reach this method.")
        }

        return ContentViewModel(topic: topic)
    }
}

// MARK: - Behavior

extension TopicListViewModel {
    final class RestorePositionBehavior: StateTransitionBehavior<TopicListViewModel, Model, Action> {
        override func preTransition(action: Action, from: Model, to: Model) {
            guard let viewModel = self.viewModel else { return }

            func saveOffset(forumKey: String) {
                S1LogDebug("Saving offset \(viewModel.tableViewOffset.value) for \(forumKey)")
                viewModel.cachedContentOffset[forumKey] = mutate(viewModel.tableViewOffset.value) { (value: inout CGPoint) in
                    value.y = value.y < 0.0 ? 0.0 : value.y
                }
            }

            /// Whenever leaving a forum, save its tableView.contentOffset
            switch (from.target, to.target) {
            case (.forum(let forum), .forum(let newForum)) where forum.key != newForum.key:
                saveOffset(forumKey: forum.key)

            case (.forum(let forum), .blank),
                 (.forum(let forum), .search):
                saveOffset(forumKey: forum.key)

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

    final class RefreshTimeCachingBehavior: StateTransitionBehavior<TopicListViewModel, Model, Action> {
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
            case (_, .loaded):
                if case .tabTapped = action {
                    viewModel.hudActionObserver.send(value: .hide(delay: 0.0))
                } else {
                    viewModel.hudActionObserver.send(value: .hide(delay: 0.3))
                }

            case (_, .loading(let loading)):
                switch (loading.target, loading.showingHUD) {
                case (.forum, true):
                    viewModel.hudActionObserver.send(value: .loading)
                case (.forum, false):
                    viewModel.hudActionObserver.send(value: .hide(delay: 0.0))
                case (.search, _):
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

            switch (to.state, action) {
            case (.loaded, .tabTapped),
                 (.loaded, .requestFinish),
                 (.loaded, .loadMoreFinish),
                 (.error, .requestFinish),
                 (.error, .loadMoreFinish),
                 (_, .reset):
                viewModel.tableViewReloadingObserver.send(value: ())
            case (_, .cloudKitUpdate(let indexPaths)):
                viewModel.tableViewCellUpdateObserver.send(value: indexPaths)
            default:
                break
            }
        }
    }

    final class SearchTextClearBehavior: StateTransitionBehavior<TopicListViewModel, Model, Action> {
        override func postTransition(action: Action, from: Model, to: Model) {
            guard let viewModel = self.viewModel else { return }

            switch action {
            case .tabTapped:
                viewModel.searchTextClearActionObserver.send(value: ())
            default:
                break
            }
        }
    }

    final class TabSelectionBehavior: StateTransitionBehavior<TopicListViewModel, Model, Action> {
        override func postTransition(action: Action, from: Model, to: Model) {
            guard let viewModel = self.viewModel else { return }

            switch (to.target, to.state) {
            case (.blank, .error(let failedTarget, _)):
                switch failedTarget {
                case .forum(let key):
                    viewModel.tabBarSelection.value = .key(key)
                case .search:
                    viewModel.tabBarSelection.value = .none
                }
            case (_, .loading(let loading)):
                switch loading.target {
                case .forum(let key):
                    viewModel.tabBarSelection.value = .key(key)
                case .search:
                    viewModel.tabBarSelection.value = .none
                }
            case (.forum(let forum), _):
                viewModel.tabBarSelection.value = .key(forum.key)
            case (.search, _), (.blank, _):
                viewModel.tabBarSelection.value = .none
            }
        }
    }

    /// Calling ODRefreshControl.endRefreshing() may cause UITableVIew request cellForRowAtIndexPath.
    /// This behavior must be performed after TableViewUpdateBehavior.
    /// See: Crashlytics #648
    final class RefreshControlBehavior: StateTransitionBehavior<TopicListViewModel, Model, Action> {
        override func postTransition(action: Action, from: Model, to: Model) {
            guard let viewModel = self.viewModel else { return }

            switch (to.target, to.state) {
            case (_, .loaded):
                viewModel.refreshControlEndRefreshingObserver.send(value: ())
            case (.blank, .error):
                viewModel.refreshControlEndRefreshingObserver.send(value: ())
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

    private func newToken() -> Int {
        dispatchPrecondition(condition: .onQueue(.main))

        let token = self.activeRequestToken + 1
        self.activeRequestToken = token
        return token
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
                let new = Model(
                    target: .forum(.init(key: forum.key, topics: updatedTopics, allResultFetched: forum.allResultFetched)),
                    state: model.value.state
                )
                transitModel(to: new, with: .cloudKitUpdate(indexPaths))
            }

        case .search(let search):
            let (updatedTopics, indexPaths) = update(topics: search.topics)
            if indexPaths.count > 0 {
                let new = Model(
                    target: .search(.init(term: search.term, topics: updatedTopics, searchID: search.searchID, page: search.page, allResultFetched: search.allResultFetched)),
                    state: model.value.state
                )
                transitModel(to: new, with: .cloudKitUpdate(indexPaths))
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
            return ".forum \(forum.key)(\(forum.topics.count))" + (forum.allResultFetched ? " All" : "")
        case .search(let search):
            return ".search \(search.term)(\(search.topics.count))" + (search.allResultFetched ? " All" : "")
        }
    }
}

extension TopicListViewModel.Model.State: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .loaded:
            return ".loaded"
        case .fetchingMore:
            return ".fetchingMore"
        case .loading(let loading):
            return ".loading \(loading.target) hud: \(loading.showingHUD)"
        case .error(let target, let message):
            return ".error \(target) \(message)"
        }
    }
}
