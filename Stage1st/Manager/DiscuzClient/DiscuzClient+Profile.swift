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

        return AF.request(baseURL + "/api/mobile/index.php", parameters: parameters)
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

        return AF.request(baseURL + "/api/mobile/index.php", parameters: parameters)
            .responseDecodable(completionHandler: completion)
    }
}
