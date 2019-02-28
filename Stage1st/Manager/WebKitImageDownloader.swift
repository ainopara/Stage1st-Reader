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
    let name: String

    private lazy var session = {
        URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: self.delegateQueue
        )
    }()

    private let delegateQueue: OperationQueue

    /// Value type of Dictionary is `Any` because `WKURLSchemeTask` is only available in iOS 11.
    private var taskMap = [URLSessionDataTask: Any]()

    public init(name: String) {
        self.name = name

        delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.name = name
        delegateQueue.qualityOfService = .utility

        super.init()
    }

    deinit {
        taskMap.keys.forEach { (task) in
            task.cancel()
        }
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

        _start(schemeTask: urlSchemeTask, with: request)
    }

    @available(iOS 11.0, *)
    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        S1LogDebug("Stop downloading \(urlSchemeTask.request)")
        _stop(schemeTask: urlSchemeTask)
    }
}

// MARK: - Helpers

private extension WebKitImageDownloader {
    @available(iOS 11.0, *)
    func _start(schemeTask: WKURLSchemeTask, with request: URLRequest) {
        delegateQueue.addOperation {
            let dataTask = self.session.dataTask(with: request)
            self.taskMap[dataTask] = schemeTask as Any
            dataTask.resume()
        }
    }

    @available(iOS 11.0, *)
    func _stop(schemeTask: WKURLSchemeTask) {
        /// We may performing data receive operation in delegate queue when this method called in main thread.
        /// We suspend delegate queue to ensure all of our stop(schemeTask:) are called and handled before calling didReceive() method in background queue.
        /// Even though delegateQueue.isSuspended is setted to ture, the task which already started when stop(schemeTask:) called will not be stopped.
        /// So we catch exception throwed from WKWebView.

        delegateQueue.addOperation {
            for (theDataTask, theSchemeTask) in self.taskMap where (theSchemeTask as! WKURLSchemeTask) === schemeTask {
                S1LogDebug("Cancel data task \(theDataTask.taskIdentifier).")
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
            if let schemeTask = self.taskMap[dataTask] as? WKURLSchemeTask {
                S1LogDebug("Task Receive Response \(schemeTask.request) \(dataTask.state == .running)")
                do {
                    try ExceptionCatcher.catchException {
                        schemeTask.didReceive(response)
                    }
                } catch {
                    S1LogWarn("\(error)")
                    AppEnvironment.current.eventTracker.recordError(error)
                }
            }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if #available(iOS 11.0, *) {
            if let schemeTask = self.taskMap[dataTask] as? WKURLSchemeTask {
                S1LogVerbose("Task Receive Data \(schemeTask.request) Running: \(dataTask.state == .running)")
                do {
                    try ExceptionCatcher.catchException {
                        schemeTask.didReceive(data)
                    }
                } catch {
                    S1LogWarn("\(error)")
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if #available(iOS 11.0, *) {
            if let schemeTask = self.taskMap[task as! URLSessionDataTask] as? WKURLSchemeTask {
                if let error = error {
                    S1LogWarn("Task Fail \(schemeTask.request) \(error)")
                    do {
                        try ExceptionCatcher.catchException {
                            schemeTask.didFailWithError(error)
                        }
                    } catch {
                        S1LogWarn("\(error)")
                    }
                } else {
                    S1LogDebug("Task Finish \(schemeTask.request)")
                    do {
                        try ExceptionCatcher.catchException {
                            schemeTask.didFinish()
                        }
                    } catch {
                        S1LogWarn("\(error)")
                    }
                }

                self.taskMap.removeValue(forKey: task as! URLSessionDataTask)
            }
        }
    }
}

// MARK: -

enum WebKitImageDownloaderError: Error {
    case invalidURL
}
