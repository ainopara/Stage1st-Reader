//
//  DiscuzClient+Search.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Alamofire
import KissXML

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

        return AF.request(baseURL + "/search.php?searchsubmit=yes", method: .post, parameters: params)
            .responseData { (response) in
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

        return AF.request(baseURL + "/search.php", parameters: params)
            .responseData { (response) in
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
