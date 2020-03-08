//
//  DataCenter.swift
//  Stage1st
//
//  Created by Zheng Li on 2/11/17.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Ainoaibo
import YapDatabase
import WebKit
import Alamofire
import ReactiveSwift
import Combine

class DataCenter: NSObject {
    let apiManager: DiscuzClient
    let tracer: S1YapDatabaseAdapter
    let cacheDatabaseManager: CacheDatabaseManager

    let formhash = CurrentValueSubject<String?, Never>(nil)
    let noticeCount: MutableProperty<NoticeCount?> = MutableProperty(nil)

    private var topicListCache = [Int: [S1Topic]]()
    private var topicListCachePageNumber = [Int: Int]()
    private var workingRequests = [Request]()

    var lastDailyTaskFinishDate: [String: Date] {
        get { AppEnvironment.current.settings.lastDailyTaskDate.value }
        set { AppEnvironment.current.settings.lastDailyTaskDate.value = newValue }
    }
    let dailyTaskSucceed = PassthroughSubject<Result<String, Error>, Never>()

    private var bag = Set<AnyCancellable>()

    init(
        apiManager: DiscuzClient,
        databaseManager: DatabaseManager,
        cacheDatabaseManager: CacheDatabaseManager
    ) {
        self.apiManager = apiManager
        tracer = S1YapDatabaseAdapter(database: databaseManager)
        self.cacheDatabaseManager = cacheDatabaseManager

        super.init()

        setupDailyTask()
    }
}

extension String: LocalizedError {
    public var errorDescription: String? {
        return self
    }
}

// MARK: - Topic List

extension DataCenter {
    func hasCache(for key: Int) -> Bool {
        return topicListCache[key] != nil
    }

    func cachedTopics(for key: Int) -> [S1Topic]? {
        return topicListCache[key]
    }

    func topics(for key: Int, completion: @escaping (Result<[S1Topic], Error>) -> Void) {
        topicsFromServer(for: key, page: 1, completion: completion)
    }

    func loadNextPage(for key: Int, completion: @escaping (Result<[S1Topic], Error>) -> Void) {
        if let currentPageNumber = topicListCachePageNumber[key] {
            topicsFromServer(for: key, page: currentPageNumber + 1, completion: completion)
        } else {
            completion(.failure("loadNextPage called when no currentPageNumber in cache."))
        }
    }

    fileprivate func updateLoginState(_ username: String?) {
        if let loginUsername = username, loginUsername != "" {
            AppEnvironment.current.settings.currentUsername.value = loginUsername
        } else {
            AppEnvironment.current.settings.currentUsername.value = nil
        }
    }

    private func topicsFromServer(for key: Int, page: Int, completion: @escaping (Result<[S1Topic], Error>) -> Void) {
        apiManager.topics(in: key, page: page) { [weak self] (result) in
            guard let strongSelf = self else { return }

            switch result {
            case .success(let parsedTopics):

                strongSelf.updateLoginState(parsedTopics.username)

                if let formhash = parsedTopics.formhash {
                    strongSelf.formhash.send(formhash)
                }

                strongSelf.noticeCount.value = parsedTopics.noticeCount

                let processedTopics = strongSelf.processAndCacheTopics(parsedTopics.topics, key: key, page: page)
                completion(.success(processedTopics))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private func eliminateDuplicatedTopics(_ topics: [S1Topic], key: Int) -> [S1Topic] {
        if let cachedTopics = topicListCache[key] {
            let filteredCachedTopics = cachedTopics.filter { oldTopic in
                topics.first(where: { newTopic in newTopic.topicID == oldTopic.topicID }) == nil
            }

            return filteredCachedTopics + topics
        } else {
            return topics
        }
    }

    private func removeStickTopics(_ topics: [S1Topic]) -> [S1Topic] {
        func isTopicNotOlderThanAllTopicsInSlice(_ topic: S1Topic, slice: ArraySlice<S1Topic>) -> Bool {
            for nextTopic in slice {
                let topicTimestamp = topic.lastReplyDate?.timeIntervalSince1970 ?? 0
                let nextTopicTimestamp = nextTopic.lastReplyDate?.timeIntervalSince1970 ?? 0

                if topicTimestamp < nextTopicTimestamp {
                    return false
                }
            }

            return true
        }

        var processedTopics = [S1Topic]()

        for (index, topic) in topics.enumerated() {
            if isTopicNotOlderThanAllTopicsInSlice(topic, slice: topics[index..<topics.count]) {
                processedTopics.append(topic)
            }
        }

        return processedTopics
    }

    private func processAndCacheTopics(_ topics: [S1Topic], key: Int, page: Int) -> [S1Topic] {
        guard topics.count > 0 else {
            if topicListCache[key] == nil {
                topicListCache[key] = []
                topicListCachePageNumber[key] = 1
            }

            return []
        }

        var processedTopics = topics

        if AppEnvironment.current.settings.hideStickTopics.value == true {
            processedTopics = removeStickTopics(processedTopics)
        }

        if page != 1 {
            processedTopics = eliminateDuplicatedTopics(processedTopics, key: key)
        }

        topicListCache[key] = processedTopics
        topicListCachePageNumber[key] = page

        return processedTopics
    }
}

// MARK: Search
extension DataCenter {
    func canMakeSearchRequest() -> Bool {
        return formhash.value != nil
    }

    func searchTopics(for keyword: String, completion: @escaping (Result<([S1Topic], String?), Error>) -> Void) {
        apiManager.search(for: keyword, formhash: formhash.value!) { [weak self] (result) in
            guard let strongSelf = self else { return }

            switch result {
            case .success((let topics, let searchID)):
                let processedTopics = topics.map { topic -> S1Topic in
                    guard let tracedTopic = strongSelf.traced(topicID: Int(truncating: topic.topicID))?.copy() as? S1Topic else {
                        return topic
                    }

                    tracedTopic.update(topic)
                    return tracedTopic
                }

                completion(.success((processedTopics, searchID)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func nextSearchPage(for searchID: String, page: Int, completion: @escaping (Result<([S1Topic], String?), Error>) -> Void) {
        apiManager.search(with: searchID, page: page) { [weak self] (result) in
            guard let strongSelf = self else { return }

            switch result {
            case .success((let topics, let newSearchID)):
                let processedTopics = topics.map { topic -> S1Topic in
                    guard let tracedTopic = strongSelf.traced(topicID: Int(truncating: topic.topicID))?.copy() as? S1Topic else {
                        return topic
                    }

                    tracedTopic.update(topic)
                    return tracedTopic
                }

                completion(.success((processedTopics, newSearchID)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Content
extension DataCenter {
    @discardableResult
    fileprivate func requestFloorsFromServer(_ topic: S1Topic, _ page: Int, _ completion: @escaping (Result<([Floor], Bool), Error>) -> Void) -> Request {
        return apiManager.floors(in: Int(truncating: topic.topicID), page: page) { [weak self] (result) in
            guard let strongSelf = self else { return }

            switch result {
            case let .success(rawFloorList):
                strongSelf.updateLoginState(rawFloorList.variables?.memberUsername)
                if let notice = rawFloorList.variables?.notice {
                    strongSelf.noticeCount.value = notice
                }

                if let latestTopic = S1Topic(rawFloorList: rawFloorList) {
                    topic.update(latestTopic)
                }

                if let formhash = rawFloorList.variables?.formhash {
                    strongSelf.formhash.send(formhash)
                }

                guard let rawFloors = rawFloorList.variables?.postList else {
                    completion(.failure("Empty floors."))
                    return
                }

                let floors = rawFloors.compactMap { Floor(rawPost: $0) }

                guard floors.count > 0 else {
                    completion(.failure("Empty floors."))
                    return
                }

                strongSelf.cacheDatabaseManager.set(floors: floors, topicID: topic.topicID.intValue, page: page, completion: {
                    completion(.success((floors, false)))
                })
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func floors(for topic: S1Topic, with page: Int, completion: @escaping (Result<([Floor], Bool), Error>) -> Void) {
        assert(!topic.isImmutable)

        if let cachedFloors = cacheDatabaseManager.floors(in: topic.topicID.intValue, page: page), cachedFloors.count > 0 {
            completion(.success((cachedFloors, true)))
        } else {
            let request = requestFloorsFromServer(topic, page, completion)
            workingRequests.append(request)
        }
    }

    func precacheFloors(for topic: S1Topic, with page: Int, shouldUpdate: Bool) {
        guard shouldUpdate || !hasPrecachedFloors(for: topic.topicID.intValue, page: page) else {
            S1LogVerbose("[Database] Precache \(topic.topicID)-\(page) hit")
            return
        }

        floors(for: topic, with: page) { result in
            switch result {
            case .success:
                S1LogDebug("[Network] Precache \(topic.topicID)-\(page) finish")
                NotificationCenter.default.post(name: .S1FloorsDidCachedNotification, object: nil, userInfo: [
                    "topicID": topic.topicID,
                    "page": page
                ])
            case let .failure(error):
                S1LogWarn("[Network] Precache \(topic.topicID)-\(page) failed. \(error)")
            }
        }
    }

    func removePrecachedFloors(for topic: S1Topic, with page: Int) {
        cacheDatabaseManager.removeFloors(in: topic.topicID.intValue, page: page)
    }

    func searchFloorInCache(by floorID: Int) -> Floor? {
        return cacheDatabaseManager.floor(id: floorID)
    }
}

// MARK: Reply

extension DataCenter {

    func reply(topic: S1Topic, text: String, successblock: @escaping () -> Void, failureBlock: @escaping (Error) -> Void) {
        guard let formhash = topic.formhash, let forumID = topic.fID else {
            failureBlock("fID or formhash missing.")
            return
        }

        apiManager.quickReply(
            topicID: Int(truncating: topic.topicID),
            forumID: Int(truncating: forumID),
            formhash: formhash,
            text: text
        ) { (result) in
            switch result {
            case .success:
                successblock()
            case .failure(let error):
                failureBlock(error)
            }
        }
    }

    func reply(floor: Floor, in topic: S1Topic, at page: Int, text: String, successblock: @escaping () -> Void, failureBlock: @escaping (Error) -> Void) {
        guard let forumID = topic.fID else {
            failureBlock("fID missing.")
            return
        }

        apiManager.replyReferenceContent(
            topicID: Int(truncating: topic.topicID),
            page: page,
            floorID: floor.id,
            forumID: Int(truncating: forumID),
            completion: { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .success(let data):
                    guard
                        let responseString = String(data: data, encoding: .utf8),
                        let parameters = Parser.replyFloorInfo(from: responseString)
                    else {
                        failureBlock("bad response from server.")
                        return
                    }

                    var mutableParameters = parameters
                    mutableParameters["replysubmit"] = "true"
                    mutableParameters["message"] = text

                    strongSelf.apiManager.reply(
                        topicID: Int(truncating: topic.topicID),
                        page: page,
                        forumID: Int(truncating: forumID),
                        parameters: mutableParameters,
                        completion: { result in
                            switch result {
                            case .success:
                                successblock()
                            case .failure(let error):
                                failureBlock(error)
                            }
                        }
                    )
                case .failure(let error):
                    failureBlock(error)
                }
            }
        )
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
        return Int(truncating: tracer.numberOfTopicsInDatabse())
    }

    func numberOfFavorite() -> Int {
        return Int(truncating: tracer.numberOfFavoriteTopicsInDatabse())
    }
}

// MARK: - User Blocking
extension DataCenter {
    func blockUser(with ID: Int) {
        tracer.blockUser(withID: ID)
        NotificationCenter.default.post(name: UserViewModel.userBlockStatusDidChangeNotification, object: nil)
    }

    func unblockUser(with ID: Int) {
        tracer.unblockUser(withID: ID)
        NotificationCenter.default.post(name: UserViewModel.userBlockStatusDidChangeNotification, object: nil)
    }

    func userIDIsBlocked(ID: Int) -> Bool {
        return tracer.userIDIsBlocked(ID)
    }
}

// MARK: - Cleaning
extension DataCenter {
    func clearTopicListCache() {
    }

    func cleaning() {
        cleanHistoryTopics()
        cleanCacheDatabase()
        cleanWebKitCache()
    }

    private func cleanHistoryTopics() {
        let duration = AppEnvironment.current.settings.historyLimit.value
        guard duration > 0 else { return }

        tracer.removeTopic(before: Date(timeIntervalSinceNow: -Double(duration)))
    }

    private func cleanCacheDatabase() {
        let cleaningCacheBeforeDate = Date(timeIntervalSinceNow: -2 * 7 * 24 * 3600)
        cacheDatabaseManager.removeFloors(lastUsedBefore: cleaningCacheBeforeDate)
        cacheDatabaseManager.cleanInvalidFloorsID()
    }

    private func cleanWebKitCache() {
        let settings = AppEnvironment.current.settings
        guard let previousCleaningDate = settings.previousWebKitCacheCleaningDate.value else {
            settings.previousWebKitCacheCleaningDate.value = Date()
            return
        }

        let cleaningCacheBeforeDate = Date(timeIntervalSinceNow: -2 * 7 * 24 * 3600)

        guard previousCleaningDate.s1_isEarlierThan(date: cleaningCacheBeforeDate) else {
            return
        }

        let websiteDataTypes = Set([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])

        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: Date.distantPast) {
            S1LogInfo("WebKit disk cache cleaned.")
            settings.previousWebKitCacheCleaningDate.value = Date()
        }
    }
}

extension DataCenter {
    func cancelRequest() {
        while let request = workingRequests.popLast() {
            request.cancel()
        }
    }
}

extension DataCenter {
    func hasPrecachedFloors(for topicID: Int, page: Int) -> Bool {
        return cacheDatabaseManager.hasFloors(in: topicID, page: page)
    }

    func hasFullPrecachedFloors(for topicID: Int, page: Int) -> Bool {
        guard let floors = cacheDatabaseManager.floors(in: topicID, page: page), floors.count >= 30 else {
            return false
        }

        return true
    }
}

// MARK: - Daily Task

private extension DataCenter {
    func setupDailyTask() {
        formhash
            .sink { [weak self] (formhash) in
                guard let strongSelf = self else { return }
                guard let formhash = formhash else { return }
                guard let currentUsername = AppEnvironment.current.settings.currentUsername.value else { return }
                guard let timezone = TimeZone(identifier: "Asia/Shanghai") else { return }

                var calendar = Calendar(identifier: .chinese)
                calendar.timeZone = timezone

                guard !calendar.isDate(Date(), inSameDayAs: strongSelf.lastDailyTaskFinishDate[currentUsername, default: .distantPast]) else { return }
                strongSelf.apiManager.dailyTask(formhash: formhash)
                    .sinkResult { [weak self] (result) in
                        guard let strongSelf = self else { return }

                        switch result {
                        case .success(let message):
                            strongSelf.lastDailyTaskFinishDate[currentUsername] = Date()
                            strongSelf.dailyTaskSucceed.send(.success(message))
                        case .failure(let error):
                            S1LogWarn("\(error)")
                            switch error {
                            case .responseValidationFailed(reason: .customValidationFailed(let error)):
                                strongSelf.lastDailyTaskFinishDate[currentUsername] = Date()
                                strongSelf.dailyTaskSucceed.send(.failure(error))
                            default:
                                break
                            }
                        }
                }
                .store(in: &strongSelf.bag)
        }
        .store(in: &bag)

        dailyTaskSucceed
            .sink { (result) in
                switch result {
                case .success(let message):
                    Toast.shared.post(message: message, duration: .second(1.0))
                case .failure(let error):
                    Toast.shared.post(message: error.localizedDescription, duration: .second(1.0))
                }
        }
        .store(in: &bag)
    }
}

// MARK: -

public extension Notification.Name {
    static let S1FloorsDidCachedNotification = Notification.Name.init(rawValue: "S1FloorDidCached")
}
