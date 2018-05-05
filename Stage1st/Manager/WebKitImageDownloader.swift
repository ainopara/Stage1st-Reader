//
//  URLSessionManager.swift
//  Stage1st
//
//  Created by Zheng Li on 24/08/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import WebKit
import CocoaLumberjack

class WebKitImageDownloader: NSObject {
    lazy var session = {
        URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: self.delegateQueue)
    }()

    let delegateQueue: OperationQueue

    /// Value type of Dictionary is `Any` because `WKURLSchemeTask` is only available in iOS 11.
    var taskMap = [URLSessionDataTask: Any]()

    override init() {
        delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.name = "ImageDownloader"
        delegateQueue.qualityOfService = .utility

        super.init()
    }

    @available(iOS 11.0, *)
    func start(schemeTask: WKURLSchemeTask, with request: URLRequest) {
        delegateQueue.addOperation {
            let dataTask = self.session.dataTask(with: request)
            self.taskMap[dataTask] = schemeTask as Any
            dataTask.resume()
        }
    }

    @available(iOS 11.0, *)
    func stop(schemeTask: WKURLSchemeTask) {
        delegateQueue.addOperation {
            for (theDataTask, theSchemeTask) in self.taskMap where (theSchemeTask as! WKURLSchemeTask) === schemeTask {
                self.taskMap.removeValue(forKey: theDataTask)
                theDataTask.cancel()
                break
            }
        }
    }
}

// MARK: - URLSessionDataDelegate

extension WebKitImageDownloader: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if #available(iOS 11.0, *) {
            if let schemeTask = taskMap[dataTask] as? WKURLSchemeTask {
                S1LogDebug("Task Receive Response \(schemeTask.request) \(dataTask.state == .running)")
                schemeTask.didReceive(response)
            }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if #available(iOS 11.0, *) {
            if let schemeTask = taskMap[dataTask] as? WKURLSchemeTask {
                S1LogVerbose("Task Receive Data \(schemeTask.request) Running: \(dataTask.state == .running)")
                schemeTask.didReceive(data)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if #available(iOS 11.0, *) {
            if let schemeTask = taskMap[task as! URLSessionDataTask] as? WKURLSchemeTask {
                if let error = error {
                    S1LogWarn("Task Fail \(schemeTask.request) \(error)")
                    schemeTask.didFailWithError(error)
                } else {
                    S1LogDebug("Task Finish \(schemeTask.request)")
                    schemeTask.didFinish()
                }

                taskMap.removeValue(forKey: task as! URLSessionDataTask)
            }
        }
    }
}

// MARK: - WKURLSchemeHandler

@available(iOS 11.0, *)
extension WebKitImageDownloader: WKURLSchemeHandler {
    @available(iOS 11.0, *)
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        S1LogDebug("Start downloading \(urlSchemeTask.request)")
        var request = urlSchemeTask.request
        guard let urlString = request.url?.absoluteString else {
            urlSchemeTask.didFailWithError(WebKitImageDownloaderError.invalidURL)
            return
        }
        request.url = URL(string: urlString.s1_replace(pattern: "^image", with: "http"))

        start(schemeTask: urlSchemeTask, with: request)
    }

    @available(iOS 11.0, *)
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        S1LogDebug("Stop downloading \(urlSchemeTask.request)")
        stop(schemeTask: urlSchemeTask)
    }
}

// MARK: -

enum WebKitImageDownloaderError: Error {
    case invalidURL
}
