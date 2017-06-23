//
//  DataCenter.swift
//  Stage1st
//
//  Created by Zheng Li on 2/11/17.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import YapDatabase
import WebKit
import CocoaLumberjack

@objcMembers
class DataCenter: NSObject {
    let apiManager: DiscuzClient
    let tracer: S1YapDatabaseAdapter
    let cacheDatabaseManager: CacheDatabaseManager
    let networkManager: S1NetworkManager

    var mahjongFaceHistorys: [MahjongFaceItem] {
        get {
            return cacheDatabaseManager.mahjongFaceHistory()
        }

        set {
            cacheDatabaseManager.set(mahjongFaceHistory: newValue)
        }
    }

    var formHash: String?

    fileprivate var topicListCache = [String: [S1Topic]]()
    fileprivate var topicListCachePageNumber = [String: Int]()

    init(client: DiscuzClient,
         databaseManager: DatabaseManager,
         cacheDatabaseManager: CacheDatabaseManager) {

        apiManager = client
        networkManager = S1NetworkManager(baseURL: client.baseURL)
        tracer = S1YapDatabaseAdapter(database: databaseManager)
        self.cacheDatabaseManager = cacheDatabaseManager
    }
}

extension String: Error {}

// MARK: - Topic List
extension DataCenter {
    func hasCache(for key: String) -> Bool {
        return topicListCache[key] != nil
    }

    func topics(for key: String, shouldRefresh: Bool, successBlock: @escaping ([S1Topic]) -> Void, failureBlock: @escaping (Error) -> Void) {
        guard let cachedTopics = topicListCache[key], !shouldRefresh else {
            topicsFromServer(for: key, page: 1, successBlock: successBlock, failureBlock: failureBlock)
            return
        }

        successBlock(cachedTopics)
    }

    func loadNextPage(for key: String, successBlock: @escaping ([S1Topic]) -> Void, failureBlock: @escaping (Error) -> Void) {
        guard let currentPageNumber = topicListCachePageNumber[key] else {
            failureBlock("loadNextPage called when no currentPageNumber in cache.")
            return
        }

        topicsFromServer(for: key, page: currentPageNumber + 1, successBlock: successBlock, failureBlock: failureBlock)
    }

    private func topicsFromServer(for key: String, page: Int, successBlock: @escaping ([S1Topic]) -> Void, failureBlock: @escaping (Error) -> Void) {
        networkManager.requestTopicListAPI(forKey: key, withPage: page as NSNumber, success: { [weak self] _, responseObject in
            DispatchQueue.global(qos: .default).async { [weak self] in
                guard let strongSelf = self else { return }

                guard let responseDict = responseObject as? [String: Any],
                    let variable = responseDict["Variables"] as? [String: Any] else {

                    failureBlock("Invalid API response format")
                    return
                }

                if let loginUsername = variable["member_username"] as? String, loginUsername != "" {
                    UserDefaults.standard.setValue(loginUsername, forKey: "InLoginStateID")
                } else {
                    UserDefaults.standard.removeObject(forKey: "InLoginStateID")
                }

                if let formhash = variable["formhash"] as? String {
                    strongSelf.formHash = formhash
                }

                let topics = S1Parser.topics(fromAPI: responseDict) as! [S1Topic]

                strongSelf.processAndCacheTopics(topics, key: key, page: page)

                successBlock(strongSelf.topicListCache[key]!)
            }
        }) { _, error in
            failureBlock(error)
        }
    }

    private func processAndCacheTopics(_ topics: [S1Topic], key: String, page: Int) {
        func topicsIsValid() -> Bool {
            return topics.count > 0
        }

        func shouldReplaceTopics() -> Bool {
            return page == 1
        }

        guard topicsIsValid() else {
            if topicListCache[key] == nil {
                topicListCache[key] = [S1Topic]()
                topicListCachePageNumber[key] = 1
            }

            return
        }

        if shouldReplaceTopics() {
            topicListCache[key] = topics
            topicListCachePageNumber[key] = page
            return
        }

        // filter duplicated topics
        let processedTopics: [S1Topic]
        if let cachedTopics = topicListCache[key] {
            let filteredTopics = topics.filter { aTopic in
                cachedTopics.first(where: { bTopic in bTopic.topicID == aTopic.topicID }) == nil
            }

            processedTopics = cachedTopics + filteredTopics
        } else {
            processedTopics = topics
        }

        // update topic cache
        topicListCache[key] = processedTopics
        topicListCachePageNumber[key] = page
    }
}

// MARK: Search
extension DataCenter {
    func canMakeSearchRequest() -> Bool {
        return formHash != nil
    }

    func searchTopics(for keyword: String, successBlock: @escaping ([S1Topic]) -> Void, failureBlock: @escaping (Error) -> Void) {
        networkManager.postSearch(forKeyword: keyword, andFormhash: formHash!, success: { [weak self] _, responseObject in
            guard let strongSelf = self else { return }

            guard let responseData = responseObject as? Data else {
                failureBlock("Unexpected response object type.")
                return
            }

            let topics = S1Parser.topics(fromSearchResultHTMLData: responseData) as! [S1Topic]
            let processedTopics = topics.map { topic -> S1Topic in
                guard let tracedTopic = strongSelf.traced(topicID: Int(topic.topicID))?.copy() as? S1Topic else {
                    return topic
                }

                return mutate(tracedTopic, change: { (value: inout S1Topic) in
                    value.update(topic)
                })
            }

            successBlock(processedTopics)
        }) { _, error in
            failureBlock(error)
        }
    }
}

// MARK: - Content
extension DataCenter {
    func floors(for topic: S1Topic, with page: Int, successBlock: @escaping ([Floor], Bool) -> Void, failureBlock: @escaping (Error) -> Void) {
        assert(!topic.isImmutable)

        if let cachedFloors = cacheDatabaseManager.floors(in: topic.topicID.intValue, page: page), cachedFloors.count > 0 {
            successBlock(cachedFloors, true)
            return
        }

        let profileStartDate = Date()
        networkManager.requestTopicContentAPI(forID: topic.topicID, withPage: page as NSNumber, success: { [weak self] _, responseObject in
            guard let strongSelf = self else { return }

            DDLogDebug("[Network] Content Finish Fetch:\(-profileStartDate.timeIntervalSinceNow)")

            guard let responseDict = responseObject as? [String: Any], let variable = responseDict["Variables"] as? [String: Any] else {
                failureBlock("Invalid API response format")
                return
            }

            if let loginUsername = variable["member_username"] as? String, loginUsername != "" {
                UserDefaults.standard.setValue(loginUsername, forKey: "InLoginStateID")
            } else {
                UserDefaults.standard.removeObject(forKey: "InLoginStateID")
            }

            if let topicFromPageResponse = S1Parser.topicInfo(fromAPI: responseDict) {
                topic.update(topicFromPageResponse)
            }

            guard let floorsFromPageResponse = S1Parser.contents(fromAPI: responseDict) as? [Floor], floorsFromPageResponse.count > 0 else {
                failureBlock("Failed to get floors.")
                return
            }

            strongSelf.cacheDatabaseManager.set(floors: floorsFromPageResponse, topicID: topic.topicID.intValue, page: page, completion: {
                successBlock(floorsFromPageResponse, false)
            })

        }) { _, error in
            failureBlock(error)
        }
    }

    func precacheFloors(for topic: S1Topic, with page: Int, shouldUpdate: Bool) {
        guard shouldUpdate || !hasPrecachedFloors(for: topic.topicID.intValue, page: UInt(page)) else {
            DDLogVerbose("[Database] Precache \(topic.topicID)-\(page) hit")
            return
        }

        floors(for: topic, with: page, successBlock: { _, _ in
            DDLogDebug("[Network] Precache \(topic.topicID)-\(page) finish")
            NotificationCenter.default.post(name: .S1FloorsDidCachedNotification, object: nil, userInfo: ["topicID": topic.topicID, "page": page])
        }) { error in
            DDLogWarn("[Network] Precache \(topic.topicID)-\(page) failed. \(error)")
        }
    }

    func removePrecachedFloors(for topic: S1Topic, with page: Int) {
        cacheDatabaseManager.removeFloors(in: topic.topicID.intValue, page: page)
    }

    func searchFloorInCache(by floorID: Int) -> Floor? {
        return cacheDatabaseManager.floor(ID: floorID)
    }
}

// MARK: - Reply
extension DataCenter {
    func reply(topic: S1Topic, text: String, successblock: @escaping () -> Void, failureBlock: @escaping (Error) -> Void) {
        guard let formhash = topic.formhash, let forumID = topic.fID else {
            failureBlock("fID or formhash missing.")
            return
        }
        let parameters = [
            "posttime": "\(Int(Date().timeIntervalSinceNow))",
            "formhash": formhash,
            "usesig": "1",
            "subject": "",
            "message": text,
        ]

        networkManager.postReply(forTopicID: topic.topicID, forumID: forumID, andParams: parameters, success: { _, _ in
            successblock()
        }) { _, error in
            failureBlock(error)
        }
    }

    func reply(floor: Floor, in topic: S1Topic, at page: Int, text: String,
               successblock: @escaping () -> Void, failureBlock: @escaping (Error) -> Void) {
        guard let forumID = topic.fID else {
            failureBlock("fID missing.")
            return
        }

        networkManager.requestReplyRefereanceContent(forTopicID: topic.topicID, withPage: page as NSNumber, floorID: floor.ID as NSNumber, forumID: forumID, success: { [weak self] _, responseObject in
            guard let strongSelf = self else { return }
            guard let responseData = responseObject as? Data,
                let responseString = String(data: responseData, encoding: .utf8),
                let mutableParameters = S1Parser.replyFloorInfo(fromResponseString: responseString) else {

                failureBlock("bad response from server.")
                return
            }

            mutableParameters["replysubmit"] = "true"
            mutableParameters["message"] = text

            strongSelf.networkManager.postReply(forTopicID: topic.topicID, withPage: page as NSNumber, forumID: forumID, andParams: mutableParameters as! [AnyHashable: Any], success: { _, _ in
                successblock()
            }, failure: { _, error in
                failureBlock(error)
            })

        }) { _, error in
            failureBlock(error)
        }
    }
}

// MARK: - Database
extension DataCenter {
    func hasViewed(topic: S1Topic) {
        tracer.hasViewed(topic)
    }

    func removeTopicFromHistory(topicID: Int) {
        tracer.removeTopic(fromHistory: topicID as NSNumber)
    }

    func removeTopicFromFavorite(topicID: Int) {
        tracer.removeTopic(fromFavorite: topicID as NSNumber)
    }

    func traced(topicID: Int) -> S1Topic? {
        return tracer.topic(byID: topicID as NSNumber)
    }

    func numberOfTopics() -> Int {
        return Int(tracer.numberOfTopicsInDatabse())
    }

    func numberOfFavorite() -> Int {
        return Int(tracer.numberOfFavoriteTopicsInDatabse())
    }
}

// MARK: - User Blocking
extension DataCenter {
    func blockUser(with ID: UInt) {
        tracer.blockUser(withID: ID)
    }

    func unblockUser(with ID: UInt) {
        tracer.unblockUser(withID: ID)
    }

    func userIDIsBlocked(ID: UInt) -> Bool {
        return tracer.userIDIsBlocked(ID)
    }
}

// MARK: - Cleaning
extension DataCenter {
    func clearTopicListCache() {
        topicListCache.removeAll()
        topicListCachePageNumber.removeAll()
    }

    func cleaning() {
        cleanHistoryTopics()
        cleanCacheDatabase()
        cleanWebKitCache()
    }

    private func cleanHistoryTopics() {
        guard let durationNumber = UserDefaults.standard.value(forKey: Constants.defaults.historyLimitKey) as? NSNumber else {
            return
        }

        guard durationNumber.doubleValue > 0.0 else {
            return
        }

        let duration = durationNumber.doubleValue

        tracer.removeTopic(before: Date(timeIntervalSinceNow: -duration))
    }

    private func cleanCacheDatabase() {
        let cleaningCacheBeforeDate = Date(timeIntervalSinceNow: -2 * 7 * 24 * 3600)
        cacheDatabaseManager.removeFloors(lastUsedBefore: cleaningCacheBeforeDate)
        cacheDatabaseManager.cleanInvalidFloorsID()
    }

    private func cleanWebKitCache() {
        guard let previousCleaningDate = UserDefaults.standard.object(forKey: Constants.defaults.previousWebKitCacheCleaningDateKey) as? Date else {
            UserDefaults.standard.set(Date(), forKey: Constants.defaults.previousWebKitCacheCleaningDateKey)
            return
        }

        let cleaningCacheBeforeDate = Date(timeIntervalSinceNow: -2 * 7 * 24 * 3600)

        guard previousCleaningDate.s1_isEarlierThan(date: cleaningCacheBeforeDate) else {
            return
        }

        let websiteDataTypes = Set([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])

        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: Date.distantPast) {
            DDLogInfo("WebKit disk cache cleaned.")
            UserDefaults.standard.set(Date(), forKey: Constants.defaults.previousWebKitCacheCleaningDateKey)
        }
    }
}

extension DataCenter {
    func cancelRequest() {
        networkManager.cancelRequest()
    }
}

extension DataCenter {
    func hasPrecachedFloors(for topicID: Int, page: UInt) -> Bool {
        return cacheDatabaseManager.hasFloors(in: topicID, page: Int(page))
    }

    func hasFullPrecachedFloors(for topicID: Int, page: UInt) -> Bool {
        guard let floors = cacheDatabaseManager.floors(in: topicID, page: Int(page)), floors.count >= 30 else {
            return false
        }

        return true
    }
}

public extension Notification.Name {
    public static let S1FloorsDidCachedNotification = Notification.Name.init(rawValue: "S1FloorDidCached")
}
