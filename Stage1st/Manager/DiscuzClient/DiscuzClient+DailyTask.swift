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

    func dailyTask(formhash: String) -> Future<Void, AFError> {
        return Future { promise in
            let urlParameters: Parameters = [
                "formhash": formhash
            ]

            let urlString = self.baseURL + "/study_daily_attendance-daily_attendance.html"

            self.session.request(urlString, method: .get, parameters: urlParameters)
                .responseString { (response) in
                    switch response.result {
                    case .success(let content):
                        if content.contains(#"<div id="messagetext" class="alert_info">"#) {
                            promise(.success(()))
                        } else {
                            promise(.failure(AFError.responseValidationFailed(reason: .customValidationFailed(error: "Failed to find alert_info in resposne HTML String."))))
                        }

                    case .failure(let afError):
                        promise(.failure(afError))
                    }
                }
        }
    }
}
