//
//  DiscuzClient+Report.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Alamofire

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

        let URLString = generateURLString(baseURL() + "/misc.php", parameters: URLParameters)

        let bodyParameters: Parameters = [
            "report_select": "其他",
            "message": reason,
            "referer": baseURL() + "/forum.php?mod=viewthread&tid=\(topicID)",
            "reportsubmit": "true",
            "rtype": "post",
            "rid": floorID,
            "fid": forumID,
            "url": "",
            "inajax": 1,
            "handlekey": "miscreport1",
            "formhash": formhash,
        ]

        return session.request(URLString, method: .post, parameters: bodyParameters)
            .responseData { response in
                completion(response.result.error)
            }
    }
}

private extension Result {
    var error: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}
