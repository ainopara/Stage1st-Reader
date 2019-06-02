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
        completion: @escaping (Result<(Forum, [S1Topic], String?, String?, NoticeCount?), Error>) -> Void
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
                let notice = rawTopicList.variables?.notice

                completion(.success((forum, topics, username, formhash, notice)))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    func topic(
        with referencePath: String,
        completion: @escaping (Result<S1Topic, Error>) -> Void
    ) -> Alamofire.Request {

        guard let url = URL(string: baseURL + "/" + referencePath) else {
            return session.request(FailureURL("Failed to generate url with baseURL: \(baseURL) path: \(referencePath)"))
                .response(completionHandler: { (response) in
//                    completion()
                })
        }

        let request = session.request(url, method: .get)
        request.redirect(using: TheRedirectHandler(newRequestProcessor: { (newRequest) in

            guard let absoluteURLString = newRequest.url?.absoluteString else {
                completion(.failure("Failed to get absoluteString from redirected request \(newRequest)"))
                return
            }

            guard let topic = Parser.extractTopic(from: absoluteURLString) else {
                completion(.failure("Failed to parse topic from absoluteString \(absoluteURLString)"))
                return
            }

            completion(.success(topic))
        }))
        return request
            .response(completionHandler: { (response) in
                guard let response = response.response else {
                    completion(.failure("Failed to get response from requesting URL: \(url)"))
                    return
                }
            })
    }
}

struct TheRedirectHandler: RedirectHandler {

    let newRequestProcessor: (URLRequest) -> Void

    init(newRequestProcessor: @escaping (URLRequest) -> Void) {
        self.newRequestProcessor = newRequestProcessor
    }

    func task(_ task: URLSessionTask, willBeRedirectedTo request: URLRequest, for response: HTTPURLResponse, completion: @escaping (URLRequest?) -> Void) {
        completion(nil)
        DispatchQueue.main.async {
            self.newRequestProcessor(request)
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
