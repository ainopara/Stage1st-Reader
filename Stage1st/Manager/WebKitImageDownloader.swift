//
//  URLSessionManager.swift
//  Stage1st
//
//  Created by Zheng Li on 24/08/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import WebKit

class WebKitImageDownloader: NSObject {

    let name: String

    private lazy var session = {
        URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: self.delegateQueue
        )
    }()

    private let delegateQueue: OperationQueue = .main

    /// Value type of Dictionary is `Any` because `WKURLSchemeTask` is only available in iOS 11.
    private var taskMap = [URLSessionDataTask: Any]()

    public init(name: String) {
        self.name = name

        super.init()
    }
}

// MARK: - WKURLSchemeHandler

@available(iOS 11.0, *)
extension WebKitImageDownloader: WKURLSchemeHandler {

    @available(iOS 11.0, *)
    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        S1LogDebug("Start downloading \(urlSchemeTask.request)")

        var request = urlSchemeTask.request

        guard let urlString = request.url?.absoluteString else {
            urlSchemeTask.didFailWithError(WebKitImageDownloaderError.invalidURL)
            return
        }

        request.url = URL(string: urlString.s1_replace(pattern: "^image", with: "http"))

        let dataTask = self.session.dataTask(with: request)
        self.taskMap[dataTask] = urlSchemeTask as Any
        dataTask.resume()
    }

    @available(iOS 11.0, *)
    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        S1LogDebug("Stop downloading \(urlSchemeTask.request)")

        for (theDataTask, theSchemeTask) in self.taskMap where (theSchemeTask as! WKURLSchemeTask) === urlSchemeTask {
            S1LogDebug("Cancel data task \(theDataTask.taskIdentifier).")
            self.taskMap.removeValue(forKey: theDataTask)
            theDataTask.cancel()
            break
        }
    }
}

// MARK: - URLSessionDataDelegate

extension WebKitImageDownloader: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        if let schemeTask = self.taskMap[dataTask] as? WKURLSchemeTask {
            S1LogDebug("Task Receive Response \(schemeTask.request) \(dataTask.state == .running)")
            schemeTask.didReceive(response)
        }

        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

        if let schemeTask = self.taskMap[dataTask] as? WKURLSchemeTask {
            S1LogVerbose("Task Receive Data \(schemeTask.request) Running: \(dataTask.state == .running)")
            schemeTask.didReceive(data)
        }

    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let schemeTask = self.taskMap[task as! URLSessionDataTask] as? WKURLSchemeTask {
            if let error = error {
                S1LogWarn("Task Fail \(schemeTask.request) \(error)")
                schemeTask.didFailWithError(error)
            } else {
                S1LogDebug("Task Finish \(schemeTask.request)")
                schemeTask.didFinish()
            }

            self.taskMap.removeValue(forKey: task as! URLSessionDataTask)
        }
    }
}

// MARK: -

enum WebKitImageDownloaderError: Error {
    case invalidURL
}
