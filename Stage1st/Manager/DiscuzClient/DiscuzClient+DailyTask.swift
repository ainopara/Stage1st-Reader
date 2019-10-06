//
//  DiscuzClient+DailyTask.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/10/4.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Alamofire
import Combine

public extension DiscuzClient {

    func dailyTask(formhash: String) -> Future<String, AFError> {
        return Future { promise in
            let urlParameters: Parameters = [
                "inajax": 1,
                "formhash": formhash
            ]

            let urlString = self.baseURL + "/study_daily_attendance-daily_attendance.html"

            self.session.request(urlString, method: .get, parameters: urlParameters)
                .responseString { (response) in
                    switch response.result {
                    case .success(let content):
                        if content.contains("succeedhandle_") {
                            if
                                let regex = try? NSRegularExpression(pattern: #"succeedhandle_\('forum.php'.+'(.+)'"#, options: []),
                                let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
                                let messageRange = Range(match.range(at: 1), in: content)
                            {
                                promise(.success(String(content[messageRange])))
                            } else {
                                promise(.success("签到成功"))
                            }
                        } else {
                            if
                                let regex = try? NSRegularExpression(pattern: #"errorhandle_\('(.+)'"#, options: []),
                                let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
                                let messageRange = Range(match.range(at: 1), in: content)
                            {
                                promise(.failure(AFError.responseValidationFailed(reason: .customValidationFailed(error: String(content[messageRange])))))
                            } else {
                                promise(.failure(AFError.responseValidationFailed(reason: .customValidationFailed(error: "签到失败"))))
                            }
                        }

                    case .failure(let afError):
                        promise(.failure(afError))
                    }
                }
        }
    }
}
