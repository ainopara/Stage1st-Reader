//
//  DiscuzClient+Reply.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Alamofire

public extension DiscuzClient {

    @discardableResult
    func replyReferenceContent(
        topicID: Int,
        page: Int,
        floorID: Int,
        forumID: Int,
        completion: @escaping (Result<Data>) -> Void
    ) -> Request {

        let parameters: Parameters = [
            "mod": "post",
            "action": "reply",
            "fid": forumID,
            "tid": topicID,
            "repquote": floorID,
            "extra": "",
            "page": page,
            "infloat": "yes",
            "handlekey": "reply",
            "inajax": 1,
            "ajaxtarget": "fwin_content_reply"
        ]

        return session.request(baseURL + "/forum.php", parameters: parameters)
            .responseData { response in
                completion(response.result)
            }
    }

    @discardableResult
    func reply(
        topicID: Int,
        page: Int,
        forumID: Int,
        parameters: [String: Any],
        completion: @escaping (Result<Void>) -> Void
    ) -> Request {

        let urlParameters: Parameters = [
            "mod": "post",
            "infloat": "yes",
            "action": "reply",
            "fid": forumID,
            "extra": "page=\(page)",
            "tid": topicID,
            "replysubmit": "yes",
            "inajax": 1
        ]

        let urlString = generateURLString(baseURL + "/forum.php", parameters: urlParameters)

        let bodyParameters: Parameters = parameters

        return session.request(urlString, method: .post, parameters: bodyParameters)
            .responseData { response in
                completion(response.result.map({ _ in () }))
        }
    }

    @discardableResult
    func quickReply(
        topicID: Int,
        forumID: Int,
        formhash: String,
        text: String,
        completion: @escaping (Result<Void>) -> Void
    ) -> Request {

        let urlParameters: Parameters = [
            "mod": "post",
            "action": "reply",
            "fid": forumID,
            "tid": topicID,
            "extra": "page=1",
            "replysubmit": "yes",
            "infloat": "yes",
            "handlekey": "fastpost",
            "inajax": 1
        ]

        let urlString = generateURLString(baseURL + "/forum.php", parameters: urlParameters)

        let bodyParameters: Parameters = [
            "posttime": "\(Int(Date().timeIntervalSinceNow))",
            "formhash": formhash,
            "usesig": "1",
            "subject": "",
            "message": text,
        ]

        return session.request(urlString, method: .post, parameters: bodyParameters)
            .responseData { response in
                completion(response.result.map({ _ in () }))
        }
    }
}
