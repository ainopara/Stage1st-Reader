//
//  DiscuzClient+Teleport.swift
//  Stage1st
//
//  Created by Zheng Li on 5/24/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire

func generateURLString(_ baseURLString: String, parameters: Parameters) -> String {
    let urlRequest = URLRequest(url: URL(string: baseURLString)!)
    let encodedURLRequest = try? URLEncoding.queryString.encode(urlRequest, with: parameters)
    return encodedURLRequest?.url?.absoluteString ?? "" // FIXME: this should not be nil.
}

// MARK: - Topic List

public extension DiscuzClient {

    struct ParsedTopics {
        let forum: Forum
        let topics: [S1Topic]
        let username: String?
        let formhash: String?
        let noticeCount: NoticeCount?
    }

    @discardableResult
    func topics(
        in forumID: Int,
        page: Int,
        completion: @escaping (Result<ParsedTopics, Error>) -> Void
    ) -> Alamofire.Request {
        let parameters: Parameters = [
            "module": "forumdisplay",
            "version": 1,
            "tpp": 50,
            "submodule": "checkpost",
            "mobile": "no",
            "fid": forumID,
            "page": page,
            "orderby": "dblastpost",
        ]

        return session.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseDecodable { (response: AFDataResponse<RawTopicList>) in
            switch response.result {
            case let .success(rawTopicList):

                if let serverErrorMessage = rawTopicList.error, serverErrorMessage != "" {
                    completion(.failure(DiscuzError.serverError(message: serverErrorMessage)))
                    return
                }

                if let serverErrorMessage = rawTopicList.message?.description, serverErrorMessage != "" {
                    completion(.failure(DiscuzError.serverError(message: serverErrorMessage)))
                    return
                }

                guard let rawTopics = rawTopicList.variables?.threadList else {
                    completion(.failure(DiscuzError.noThreadListReturned(jsonString: "TODO")))
                    return
                }

                guard let rawForum = rawTopicList.variables?.forum, let forum = Forum(rawForum: rawForum) else {
                    completion(.failure(DiscuzError.noFieldInfoReturned(jsonString: "TODO")))
                    return
                }

                let topics = rawTopics
                    .map { S1Topic(rawTopic: $0, forumID: forum.id) }
                    .compactMap { $0 }

                let username = rawTopicList.variables?.memberUsername
                let formhash = rawTopicList.variables?.formhash
                let notice = rawTopicList.variables?.notice

                let parsedTopics = ParsedTopics(
                    forum: forum,
                    topics: topics,
                    username: username,
                    formhash: formhash,
                    noticeCount: notice
                )

                completion(.success(parsedTopics))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Content

public extension DiscuzClient {

    @discardableResult
    func floors(
        in topicID: Int,
        page: Int,
        completion: @escaping (Result<RawFloorList, Error>) -> Void
    ) -> Alamofire.Request {

        let parameters: Parameters = [
            "module": "viewthread",
            "version": 1,
            "ppp": AppEnvironment.current.settings.postPerPage.value,
            "submodule": "checkpost",
            "mobile": "no",
            "tid": topicID,
            "page": page,
        ]

        return session.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseDecodable { (response: AFDataResponse<RawFloorList>) in
            switch response.result {
            case let .success(rawFloorList):
                if let serverErrorMessage = rawFloorList.error, serverErrorMessage != "" {
                    completion(.failure(DiscuzError.serverError(message: serverErrorMessage)))
                    return
                }

                if let serverErrorMessage = rawFloorList.message?.description, serverErrorMessage != "" && (rawFloorList.variables?.postList ?? []).count == 0 {
                    completion(.failure(DiscuzError.serverError(message: serverErrorMessage)))
                    return
                }

                completion(.success(rawFloorList))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func floors(in topicID: Int, page: Int) async throws -> RawFloorList {
        return try await withCheckedThrowingContinuation { continuation in
            floors(in: topicID, page: page) { result in continuation.resume(with: result) }
        }
    }
}
