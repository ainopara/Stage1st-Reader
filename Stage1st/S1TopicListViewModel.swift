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

public final class S1TopicListViewModel: NSObject {
    public let dataCenter: S1DataCenter
    var viewMappings: YapDatabaseViewMappings?
    var databaseConnection: YapDatabaseConnection = MyDatabaseManager.uiDatabaseConnection
    lazy var searchQueue = YapDatabaseSearchQueue()

    init(dataCenter: S1DataCenter) {
        self.dataCenter = dataCenter
        super.init()

        // pre-load to spead up respongding to first tap on archive button.
        updateFilter("", key: "History")

        initializeMappings()
    }

    func topicListForKey(_ key: String, refresh: Bool, success: @escaping (_ topicList: [S1Topic]) -> Void, failure: @escaping (_ error: Error) -> Void) {
        dataCenter.topics(forKey: key, shouldRefresh: refresh, success: { [weak self] topicList in
            guard let strongSelf = self else { return }
            var processedList = [S1Topic]()
            for topic in topicList {
                processedList.append(strongSelf.topicWithTracedDataForTopic(topic))
            }
            ensureMainThread({
                success(processedList)
            })

        }, failure: { error in
            ensureMainThread({
                failure(error)
            })
        })
    }

    func loadNextPageForKey(_ key: String, success: @escaping (_ topicList: [S1Topic]) -> Void, failure: @escaping (_ error: Error) -> Void) {
        dataCenter.loadNextPage(forKey: key, success: { [weak self] topicList in
            guard let strongSelf = self else { return }
            var processedList = [S1Topic]()
            for topic in topicList {
                processedList.append(strongSelf.topicWithTracedDataForTopic(topic))
            }
            ensureMainThread({
                success(processedList)
            })
        }, failure: { error in
            ensureMainThread({
                failure(error)
            })
        })
    }

    func numberOfSections() -> UInt {
        return viewMappings?.numberOfSections() ?? 1
    }

    func numberOfItemsInSection(_ section: UInt) -> UInt {
        return viewMappings?.numberOfItems(inSection: section) ?? 0
    }

    func unfavoriteTopicAtIndexPath(_ indexPath: IndexPath) {
        if let topic = topicAtIndexPath(indexPath) {
            self.dataCenter.removeTopic(fromFavorite: topic.topicID)
        }
    }

    func deleteTopicAtIndexPath(_ indexPath: IndexPath) {
        if let topic = topicAtIndexPath(indexPath) {
            self.dataCenter.removeTopic(fromHistory: topic.topicID)
        }
    }

    func topicWithTracedDataForTopic(_ topic: S1Topic) -> S1Topic {
        if let tracedTopic = dataCenter.tracedTopic(topic.topicID)?.copy() as? S1Topic {
            tracedTopic.update(topic)
            return tracedTopic
        } else {
            return topic
        }
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
        var topic: S1Topic?
        databaseConnection.read { transaction in
            if let
                ext = transaction.ext(Ext_searchResultView_Archive) as? YapDatabaseViewTransaction,
                let viewMappings = self.viewMappings {
                topic = ext.object(at: indexPath, with: viewMappings) as? S1Topic
            }
        }

        return topic
    }

    func updateFilter(_ searchText: String, key: String) {
        let favoriteMark = key == "Favorite" ? "FY" : "F*"
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
        self.databaseConnection.read { transaction in
            self.viewMappings?.update(with: transaction)
        }
    }

    func searchBarPlaceholderStringForCurrentKey(_ key: String) -> String {
        let count = key == "Favorite" ? self.dataCenter.numberOfFavorite() : self.dataCenter.numberOfTopics()
        return NSString(format: NSLocalizedString("TopicListView_SearchBar_Detail_Hint", comment: "Search") as NSString, count) as String
    }
}
