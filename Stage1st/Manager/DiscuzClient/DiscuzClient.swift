//
//  DiscuzClient.swift
//  Stage1st
//
//  Created by Zheng Li on 5/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Alamofire

public final class DiscuzClient: NSObject {
    public let baseURL: String

    let session: Session

    public init(baseURL: String, configuration: URLSessionConfiguration) {
        self.baseURL = baseURL
        self.session = Session(
            configuration: configuration,
            redirectHandler: Redirector(behavior: Redirector.Behavior.modify({ (task, request, response) -> URLRequest? in
                if task.originalRequest?.url?.absoluteString == request.url?.absoluteString {
                    S1LogWarn("Redirect to self detected! request \(String(describing: task.originalRequest?.url?.absoluteString)) will redirect to \(String(describing: request.url?.absoluteString))")
                    AppEnvironment.current.eventTracker.recordError(NSError(
                        domain: "S1RedirectIssue",
                        code: 0,
                        userInfo: [
                            "originalRequest": task.originalRequest?.url?.absoluteString ?? "",
                            "currentRequest": task.currentRequest?.url?.absoluteString ?? "",
                            "redirectedTo": request.url?.absoluteString ?? ""
                        ]
                    ))
                    return request
                } else {
                    S1LogDebug("request \(String(describing: task.originalRequest?.url?.absoluteString)) will redirect to \(String(describing: request.url?.absoluteString))")
                    return request
                }
            }))
        )
        super.init()
    }
}

extension DiscuzClient {
    static let loginStatusDidChangeNotification = Notification.Name.init(rawValue: "DiscuzLoginStatusDidChangeNotification")
}

struct FailureURL: URLConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    func asURL() throws -> URL {
        throw message
    }
}
