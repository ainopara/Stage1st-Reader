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

    @discardableResult
    func topics(
        in forumID: Int,
        page: Int,
        completion: @escaping (Result<(Forum, [S1Topic], String?, String?)>) -> Void
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

        return session.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseDecodable { (response: DataResponse<RawTopicList>) in
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

                completion(.success((forum, topics, username, formhash)))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    func topic(
        with referencePath: String,
        completion: @escaping (Result<S1Topic>) -> Void
    ) -> Alamofire.Request {

        guard let url = URL(string: baseURL)?.appendingPathComponent(referencePath) else {
            return session.request(FailureURL("Failed to generate url with baseURL: \(baseURL) path: \(referencePath)"))
                .response(completionHandler: { (response) in
//                    completion()
                })
        }

        let request = session.request(url, method: .get)
        return request
            .response(completionHandler: { (response) in
                guard let response = response.response else {
                    completion(.failure("Failed to get response from requesting URL: \(url)"))
                    return
                }
            })
    }
}

// MARK: - Content

public extension DiscuzClient {

    @discardableResult
    func floors(
        in topicID: Int,
        page: Int,
        completion: @escaping (Result<RawFloorList>) -> Void
    ) -> Alamofire.Request {

        let parameters: Parameters = [
            "module": "viewthread",
            "version": 1,
            "ppp": 30,
            "submodule": "checkpost",
            "mobile": "no",
            "tid": topicID,
            "page": page,
        ]

        return session.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseDecodable { (response: DataResponse<RawFloorList>) in
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
}
