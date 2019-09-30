//
//  S1ArchiveListViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/5/23.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation
import YapDatabase.YapDatabaseSearchResultsView
import ReactiveSwift

final class S1ArchiveListViewModel {
    enum State: Equatable {
        case history
        case favorite
    }

    let currentState = MutableProperty(State.history)

    let dataCenter: DataCenter = AppEnvironment.current.dataCenter
    let databaseConnection: YapDatabaseConnection = AppEnvironment.current.databaseManager.uiDatabaseConnection
    var viewMappings: YapDatabaseViewMappings?
    let searchQueue = YapDatabaseSearchQueue()

    // Inputs
    let searchingTerm = MutableProperty("")
    let traitCollection = MutableProperty(UITraitCollection())
    let segmentControlIndex = MutableProperty(0)

    // Internal
    let cellTitleAttributes = MutableProperty([NSAttributedString.Key: Any]())
    let paletteNotification = MutableProperty(())
    let databaseChangedNotification = MutableProperty([Notification]())

    // Output
    let tableViewReloading: Signal<(), Never>
    private let tableViewReloadingObserver: Signal<(), Never>.Observer

    let tableViewCellUpdate: Signal<[IndexPath], Never>
    private let tableViewCellUpdateObserver: Signal<[IndexPath], Never>.Observer

    let searchBarPlaceholderText = MutableProperty("")

    // MARK: -

    init() {
        (self.tableViewReloading, self.tableViewReloadingObserver) = Signal<(), Never>.pipe()
        (self.tableViewCellUpdate, self.tableViewCellUpdateObserver) = Signal<[IndexPath], Never>.pipe()

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
            .producer.map { [weak self] (state, _) -> String in
                guard let strongSelf = self else { return "" }
                switch state {
                case .favorite:
                    let count = strongSelf.dataCenter.numberOfFavorite()
                    return String(
                        format: NSLocalizedString("TopicListViewController.SearchBar_Detail_Hint", comment: "Search"),
                        NSNumber(value: count)
                    )
                case .history:
                    let count = strongSelf.dataCenter.numberOfTopics()
                    return String(
                        format: NSLocalizedString("TopicListViewController.SearchBar_Detail_Hint", comment: "Search"),
                        NSNumber(value: count)
                    )
                }
            }
            .skipRepeats()

        MutableProperty
            .combineLatest(searchingTerm, currentState)
            .producer
            .skipRepeats { (current, previous) -> Bool in
                return current.0 == previous.0 && current.1 == previous.1
            }
            .startWithValues { [weak self] (term, state) in
                guard let strongSelf = self else { return }
                strongSelf._updateFilter(searchText: term, state: state)
            }

        paletteNotification <~ NotificationCenter.default.reactive
            .notifications(forName: .APPaletteDidChange)
            .map { _ in return () }

        cellTitleAttributes <~ MutableProperty
            .combineLatest(traitCollection, paletteNotification)
            .map { (traitCollection, _) in return traitCollection }
            .map { (traitCollection) in
                let paragraphStype = NSMutableParagraphStyle()
                paragraphStype.lineBreakMode = .byWordWrapping
                paragraphStype.alignment = .left

                let font: UIFont
                switch traitCollection.horizontalSizeClass {
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

        initializeMappings()
    }

    // MARK: Input

    func segmentControlIndexChanged(newValue: Int) {
        segmentControlIndex.value = newValue

        switch newValue {
        case 0:
            transitState(to: .history)
        case 1:
            transitState(to: .favorite)
        default:
            S1FatalError("Unknown segment index \(newValue)")
        }
    }

    func transitState(to newState: State) {
        self.currentState.value = newState
    }

    func unfavoriteTopicAtIndexPath(_ indexPath: IndexPath) {
        assert(currentState.value == .favorite, "unfavoriteTopicAtIndexPath should only be called when showing favorite list.")

        if let topic = archivedTopic(at: indexPath) {
            dataCenter.removeTopicFromFavorite(topicID: topic.topicID.intValue)
        }
    }

    func deleteTopicAtIndexPath(_ indexPath: IndexPath) {
        assert(currentState.value == .history, "deleteTopicAtIndexPath should only be called when showing history list.")

        if let topic = archivedTopic(at: indexPath) {
            dataCenter.removeTopicFromHistory(topicID: topic.topicID.intValue)
        }
    }

    // MARK: Output

    func numberOfSections() -> Int {
        if let result = viewMappings?.numberOfSections() {
            return Int(result)
        } else {
            return 0
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

extension S1ArchiveListViewModel {
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

extension S1ArchiveListViewModel {
    func cellViewModel(at indexPath: IndexPath) -> TopicListCellViewModel {
        guard let unwrappedTopic = archivedTopic(at: indexPath) else {
            S1FatalError("Expecting topic at \(indexPath) exist but get nil.")
        }

        let attributedTitle: NSAttributedString

        let title = (unwrappedTopic.title ?? "").replacingOccurrences(of: "\n", with: "")
        let mutableAttributedTitle = NSMutableAttributedString(string: title, attributes: cellTitleAttributes.value)
        let termRange = (title as NSString).range(of: searchingTerm.value, options: [.caseInsensitive, .widthInsensitive])
        mutableAttributedTitle.addAttributes([.foregroundColor: AppEnvironment.current.colorManager.colorForKey("topiclist.cell.title.highlight")], range: termRange)
        attributedTitle = mutableAttributedTitle

        return TopicListCellViewModel(
            topic: unwrappedTopic,
            isPinningTop: false,
            attributedTitle: attributedTitle
        )
    }

    func contentViewModel(at indexPath: IndexPath) -> ContentViewModel {
        guard let unwrappedTopic = archivedTopic(at: indexPath) else {
            S1FatalError("Expecting topic at \(indexPath) exist but get nil.")
        }

        return ContentViewModel(topic: unwrappedTopic)
    }
}

// MARK: YapDatabase

extension S1ArchiveListViewModel {
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

    func archivedTopic(at indexPath: IndexPath) -> S1Topic? {
        var topic: S1Topic?
        databaseConnection.read { transaction in
            if let ext = transaction.ext(Ext_searchResultView_Archive) as? YapDatabaseViewTransaction, let viewMappings = self.viewMappings {
                topic = ext.object(at: indexPath, with: viewMappings) as? S1Topic
            } else {
                let ext = transaction.ext(Ext_searchResultView_Archive) as? YapDatabaseViewTransaction
                let viewMappings = self.viewMappings
                S1LogError("Topic is nil because \(String(describing: ext)) or \(String(describing: viewMappings)) is nil or extension cound not find S1Topic object.")
            }
        }
        return topic
    }

    private func _updateFilter(searchText: String, state: State) {
        let favoriteMark = state == .favorite ? "FY" : "F*"
        let query = "favorite:\(favoriteMark) title:\(searchText)*"
        S1LogDebug("Update filter: \(query)")

        searchQueue.enqueueQuery(query)

        AppEnvironment.current.databaseManager.bgDatabaseConnection.asyncReadWrite { transaction in
            guard let ext = transaction.ext(Ext_searchResultView_Archive) as? YapDatabaseSearchResultsViewTransaction else {
                return
            }

            ext.performSearch(with: self.searchQueue)
        }
    }

    private func _handleDatabaseChanged(with notifications: [Notification]) {
        if viewMappings == nil {
            assert(false, "initializeMappings is called in init method so we should not fall into this state.")
            initializeMappings()
        } else {
            updateMappings()
        }

        tableViewReloadingObserver.send(value: ())
    }
}
