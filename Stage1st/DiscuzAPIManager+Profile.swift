//
//  DiscuzAPIManager+Profile.swift
//  Stage1st
//
//  Created by Zheng Li on 5/24/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire
import JASON

extension DiscuzAPIManager {
    func profile(userID: Int, responseBlock:(result: Result<User, NSError>) -> Void) -> Request {
        let parameters: [String: AnyObject] = ["module": "profile", "version": 1, "uid": userID, "mobile": "no"]
        return Alamofire.request(.GET, baseURL + "/api/mobile/index.php", parameters: parameters, encoding: .URL, headers: nil).responseJASON { (response) in
            switch response.result {
            case .Success(let json):
                guard let user = User(json: json) else {
                    let error = NSError(domain: "Stage1stReaderDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user info."])
                    responseBlock(result: .Failure(error))
                    return
                }
                responseBlock(result: .Success(user))
            case .Failure(let error):
                responseBlock(result: .Failure(error))
            }
        }
    }
}
