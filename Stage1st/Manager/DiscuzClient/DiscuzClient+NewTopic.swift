//
//  DiscuzClient+NewTopic.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/6/10.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation
import Alamofire

public extension DiscuzClient {

    @discardableResult
    func newTopic(
        forumID: Int,
        typeID: Int,
        formhash: String,
        subject: String,
        message: String,
        saveAsDraft: Bool,
        noticeUser: Bool,
        completion: @escaping (Result<String, AFError>) -> Void
    ) -> Request {

        let urlParameters: Parameters = [
            "mod": "post",
            "action": "newthread",
            "fid": forumID,
            "extra": "",
            "topicsubmit": "yes",
        ]

        let urlString = generateURLString(baseURL + "/forum.php", parameters: urlParameters)

        var bodyParameters: Parameters = [
            "posttime": "\(Int(Date().timeIntervalSinceNow))",
            "formhash": formhash,
            "usesig": "1",
            "typeid": typeID,
            "subject": subject,
            "message": message,
            "save": saveAsDraft ? "1" : ""
        ]

        if noticeUser {
            bodyParameters["allownoticeauthor"] = "1"
        }

        return session.request(urlString, method: .post, parameters: bodyParameters)
            .responseString { response in
                completion(response.result)
        }
    }
}
