//
//  S1TopicListViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 5/19/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
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

        initializeMappings()
    }

    func topicListForKey(key: String, refresh: Bool, success: (topicList: [S1Topic]) -> Void, failure: (error: NSError) -> Void) {
        self.dataCenter.topicsForKey(key, shouldRefresh: refresh, success: success, failure: failure)
    }

    func numberOfSections() -> UInt {
        return self.viewMappings?.numberOfSections() ?? 1
    }

    func numberOfItemsInSection(section: UInt) -> UInt {
        return self.viewMappings?.numberOfItemsInSection(section) ?? 0
    }

    func unfavoriteTopicAtIndexPath(indexPath: NSIndexPath) {
        if let topic = self.topicAtIndexPath(indexPath) {
            self.dataCenter.removeTopicFromFavorite(topic.topicID)
        }
    }

    func deleteTopicAtIndexPath(indexPath: NSIndexPath) {
        if let topic = self.topicAtIndexPath(indexPath) {
            self.dataCenter.removeTopicFromHistory(topic.topicID)
        }
    }

    func topicWithTracedDataForTopic(topic: S1Topic) -> S1Topic {
        if let tracedTopic = self.dataCenter.tracedTopic(topic.topicID)?.copy() as? S1Topic {
            tracedTopic.absorbTopic(topic)
            return tracedTopic
        } else {
            return topic
        }
    }
}

// MARK: YapDatabase
extension S1TopicListViewModel {

    func initializeMappings() {
        databaseConnection.readWithBlock { (transaction) in
            if transaction.ext(Ext_FullTextSearch_Archive) != nil {
                self.viewMappings = YapDatabaseViewMappings(groupFilterBlock: { (group, transaction) -> Bool in
                    return true
                }, sortBlock: { (group1, group2, transaction) -> NSComparisonResult in
                    return S1Formatter.sharedInstance().compareDateString(group1, withDateString: group2)
                }, view: Ext_searchResultView_Archive)
                self.viewMappings?.updateWithTransaction(transaction)
            } else {
                // The view isn't ready yet.
                // We'll try again when we get a databaseConnectionDidUpdate notification.
            }
        }
    }

    func topicAtIndexPath(indexPath: NSIndexPath) -> S1Topic? {
        var topic: S1Topic? = nil
        databaseConnection.readWithBlock { (transaction) in
            if let
                ext = transaction.ext(Ext_searchResultView_Archive) as? YapDatabaseViewTransaction,
                viewMappings = self.viewMappings {
                topic = ext.objectAtIndexPath(indexPath, withMappings: viewMappings) as? S1Topic
            }
        }

        return topic
    }

    func updateFilter(searchText: String, key: String) {
        let favoriteMark = key == "Favorite" ? "FY" : "F*"
        let query = "favorite:\(favoriteMark) title:\(searchText)*"
        DDLogDebug("[TopicListVC] Update filter: \(query)")
        searchQueue.enqueueQuery(query)
        MyDatabaseManager.bgDatabaseConnection.readWriteWithBlock { (transaction) in
            if let ext = transaction.ext(Ext_searchResultView_Archive) as? YapDatabaseSearchResultsViewTransaction {
                ext.performSearchWithQueue(self.searchQueue)
            }
        }
    }

    func updateMappings() {
        self.databaseConnection.readWithBlock { (transaction) in
            self.viewMappings?.updateWithTransaction(transaction)
        }
    }

    func searchBarPlaceholderStringForCurrentKey(key: String) -> String {
        let count = key == "Favorite" ? self.dataCenter.numberOfFavorite() : self.dataCenter.numberOfTopics()
        return NSString(format: NSLocalizedString("TopicListView_SearchBar_Detail_Hint", comment:"Search"), count) as String
    }
}
