//
//  DiscuzClient+Profile.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Alamofire

public extension DiscuzClient {

    @discardableResult
    func profile(
        userID: Int,
        completion: @escaping (Result<User>) -> Void
    ) -> Request {

        let parameters: Parameters = [
            "module": "profile",
            "version": 1,
            "uid": userID,
            "mobile": "no",
        ]

        return session.request(baseURL + "/api/mobile/index.php", parameters: parameters)
            .responseDecodable { (response: DataResponse<User>) in
                switch response.result {
                case let .success(user):
                    completion(.success(user))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
    }

    @discardableResult
    func notices(
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

        return session.request(baseURL + "/api/mobile/index.php", parameters: parameters)
            .responseDecodable(completionHandler: completion)
    }

    @discardableResult
    func threadList(
        for userID: Int,
        page: Int,
        completion: @escaping (DataResponse<Data>) -> Void
    ) -> DataRequest {

        let parameters: Parameters = [
            "mod": "space",
            "uid": userID,
            "do": "thread",
            "view": "me",
            "from": "space",
            "type": "thread",
            "page": page,
            "order": "dateline"
        ]

        return session.request(baseURL + "/home.php", parameters: parameters)
            .responseData(completionHandler: completion)
    }

    @discardableResult
    func replyList(
        for userID: Int,
        page: Int,
        completion: @escaping (DataResponse<Data>) -> Void
    ) -> DataRequest {

        let parameters: Parameters = [
            "mod": "space",
            "uid": userID,
            "do": "thread",
            "view": "me",
            "from": "space",
            "type": "reply",
            "page": page,
            "order": "dateline"
        ]

        return session.request(baseURL + "/home.php", parameters: parameters)
            .responseData(completionHandler: completion)
    }
}
