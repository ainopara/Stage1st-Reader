//
//  URLSessionManager.swift
//  Stage1st
//
//  Created by Zheng Li on 24/08/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import WebKit

class URLSessionManager: NSObject, URLSessionDataDelegate {
    static let shared = URLSessionManager()
    lazy var session = {
        URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }()

    var taskMap = [URLSessionDataTask: Any]()

    override init() {
        super.init()
    }

    @available(iOS 11.0, *)
    func start(schemeTask: WKURLSchemeTask, with request: URLRequest) {
        let dataTask = session.dataTask(with: request)
        taskMap[dataTask] = schemeTask as Any
        dataTask.resume()
    }

    @available(iOS 11.0, *)
    func stop(schemeTask: WKURLSchemeTask) {
        // TODO:
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if #available(iOS 11.0, *) {
            let schemeTask = taskMap[dataTask] as! WKURLSchemeTask
            schemeTask.didReceive(response)
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if #available(iOS 11.0, *) {
            let schemeTask = taskMap[dataTask] as! WKURLSchemeTask
            schemeTask.didReceive(data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if #available(iOS 11.0, *) {
            let schemeTask = taskMap[task as! URLSessionDataTask] as! WKURLSchemeTask
            if let error = error {
                schemeTask.didFailWithError(error)
            } else {
                schemeTask.didFinish()
            }
        }
    }
}
