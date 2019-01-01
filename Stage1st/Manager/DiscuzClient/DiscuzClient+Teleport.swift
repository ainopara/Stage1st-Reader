//
//  DiscuzClient+Teleport.swift
//  Stage1st
//
//  Created by Zheng Li on 5/24/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire
import KissXML

func generateURLString(_ baseURLString: String, parameters: Parameters) -> String {
    let urlRequest = URLRequest(url: URL(string: baseURLString)!)
    let encodedURLRequest = try? URLEncoding.queryString.encode(urlRequest, with: parameters)
    return encodedURLRequest?.url?.absoluteString ?? "" // FIXME: this should not be nil.
}

// MARK: - Topic List
public extension DiscuzClient {

    @discardableResult
    public func topics(
        in fieldID: Int,
        page: Int,
        completion: @escaping (Result<(Field, [S1Topic], String?, String?)>) -> Void
    ) -> Alamofire.Request {
        let parameters: Parameters = [
            "module": "forumdisplay",
            "version": 1,
            "tpp": 50,
            "submodule": "checkpost",
            "mobile": "no",
            "fid": fieldID,
            "page": page,
            "orderby": "dblastpost",
        ]

        return AF.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseDecodable { (response: DataResponse<RawTopicList>) in
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

                guard let rawForum = rawTopicList.variables?.forum, let forum = Field(rawForum: rawForum) else {
                    completion(.failure(DiscuzError.noFieldInfoReturned(jsonString: "TODO")))
                    return
                }

                let topics = rawTopics
                    .map { S1Topic(rawTopic: $0, fieldID: forum.id) }
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
            return AF.request(FailureURL("Failed to generate url with baseURL: \(baseURL) path: \(referencePath)"))
                .response(completionHandler: { (response) in
//                    completion()
                })
        }
        let request = AF.request(url, method: .get)
//        request.delegate
        return request.response(completionHandler: { (response) in
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
    public func floors(
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

        return AF.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseDecodable { (response: DataResponse<RawFloorList>) in
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

//                let topicFromPageResponse = S1Parser.topicInfo(fromAPI: jsonDictionary)
//                let floorsFromPageResponse = S1Parser.contents(fromAPI: jsonDictionary)

//                guard floorsFromPageResponse.count > 0 else {
//                    completion(.failure("Empty floors."))
//                    return
//                }

                completion(.success(rawFloorList))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Profile
public extension DiscuzClient {
    @discardableResult
    public func profile(
        userID: Int,
        completion: @escaping (Result<User>) -> Void
    ) -> Request {
        let parameters: Parameters = [
            "module": "profile",
            "version": 1,
            "uid": userID,
            "mobile": "no",
        ]

        return AF.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseDecodable { (response: DataResponse<User>) in
            switch response.result {
            case let .success(user):
                completion(.success(user))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    public func notices(
        page: Int,
        completion: @escaping (DataResponse<RawNoticeList>) -> Void
    ) -> DataRequest {
        let parameters: Parameters = [
            "module": "mynotelist",
            "version": 2,
            "view": "mypost",
            "page": page,
            "mobile": "no",
        ]

        return AF.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseDecodable(completionHandler: completion)
    }
}

// MARK: - Report
public extension DiscuzClient {
    @discardableResult
    func report(
        topicID: String,
        floorID: String,
        forumID: String,
        reason: String,
        formhash: String,
        completion: @escaping (Error?) -> Void
    ) -> Request {
        let URLParameters: Parameters = [
            "mod": "report",
            "inajax": 1,
        ]

        let URLString = generateURLString(baseURL + "/misc.php", parameters: URLParameters)

        let bodyParameters: Parameters = [
            "report_select": "其他",
            "message": reason,
            "referer": baseURL + "/forum.php?mod=viewthread&tid=\(topicID)",
            "reportsubmit": "true",
            "rtype": "post",
            "rid": floorID,
            "fid": forumID,
            "url": "",
            "inajax": 1,
            "handlekey": "miscreport1",
            "formhash": formhash,
        ]

        return AF.request(URLString, method: .post, parameters: bodyParameters).responseData { response in
            completion(response.result.error)
        }
    }
}

// MARK: - Search

public extension DiscuzClient {
    @discardableResult
    func search(
        for keyword: String,
        formhash: String,
        completion: @escaping (Result<([S1Topic], String?)>) -> Void
    ) -> Request {
        let params: Parameters = [
            "mod": "forum",
            "formhash": formhash,
            "srchtype": "title",
            "srhfid": "",
            "srhlocality": "forum::index",
            "srchtxt": keyword,
            "searchsubmit": "true"
        ]

        return AF.request(baseURL + "/search.php?searchsubmit=yes", method: .post, parameters: params).responseData { (response) in
            switch response.result {
            case .success(let data):
                guard let document = try? DDXMLDocument(data: data, options: 0) else {
                    completion(.failure(DiscuzError.searchResultParseFailed))
                    return
                }

                let elements = (try? document.elements(for: "//div[@id='threadlist']/ul/li[@class='pbw']")) ?? []
                S1LogDebug("Search result topic count: \(elements.count)")
                let topics = elements.compactMap { S1Topic(element: $0) }

                var searchID: String?
                let theNextPageLinks = (try? document.nodes(forXPath: "//div[@class='pg']/a[@class='nxt']/@href")) ?? []
                if
                    let rawNextPageURL = theNextPageLinks.first?.stringValue,
                    let nextPageURL = rawNextPageURL.gtm_stringByUnescapingFromHTML(),
                    let queryItems = URLComponents(string: nextPageURL)?.queryItems,
                    let theSearchID = queryItems.first(where: { $0.name == "searchid" })?.value
                {
                    searchID = theSearchID
                }

                completion(.success((topics, searchID)))

            case .failure(let error):
                completion(.failure(DiscuzError.serverError(message: error.localizedDescription)))
            }
        }
    }

    @discardableResult
    func search(
        with searchID: String,
        page: Int,
        completion: @escaping (Result<([S1Topic], String?)>) -> Void
    ) -> Request {
        let params: Parameters = [
            "mod": "forum",
            "searchid": searchID,
            "orderby": "lastpost",
            "ascdesc": "desc",
            "page": page,
            "searchsubmit": "yes"
        ]

        return AF.request(baseURL + "/search.php", parameters: params).responseData { (response) in
            switch response.result {
            case .success(let data):
                guard let document = try? DDXMLDocument(data: data, options: 0) else {
                    completion(.failure(DiscuzError.searchResultParseFailed))
                    return
                }

                let elements = (try? document.elements(for: "//div[@id='threadlist']/ul/li[@class='pbw']")) ?? []
                S1LogDebug("Search result page \(page) topic count: \(elements.count)")
                let topics = elements.compactMap { S1Topic(element: $0) }

                var searchID: String?
                let theNextPageLinks = (try? document.nodes(forXPath: "//div[@class='pg']/a[@class='nxt']/@href")) ?? []
                if
                    let rawNextPageURL = theNextPageLinks.first?.firstText,
                    let nextPageURL = rawNextPageURL.gtm_stringByUnescapingFromHTML(),
                    let queryItems = URLComponents(string: nextPageURL)?.queryItems,
                    let theSearchID = queryItems.first(where: { $0.name == "searchid" })?.value
                {
                    searchID = theSearchID
                }

                completion(.success((topics, searchID)))

            case .failure(let error):
                completion(.failure(DiscuzError.serverError(message: error.localizedDescription)))
            }
        }
    }
}
