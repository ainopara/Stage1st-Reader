//
//  URLSessionManager.swift
//  Stage1st
//
//  Created by Zheng Li on 24/08/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import WebKit
import CocoaLumberjack

class WebKitImageDownloader: NSObject, URLSessionDataDelegate {
    static let shared = WebKitImageDownloader()
    lazy var session = {
        URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }()

    var taskMap = [URLSessionDataTask: Any]()

    private override init() {
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
        for (theDataTask, theSchemeTask) in taskMap where (theSchemeTask as! WKURLSchemeTask) === schemeTask {
            taskMap.removeValue(forKey: theDataTask)
            theDataTask.cancel()
            break
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if #available(iOS 11.0, *) {
            if let schemeTask = taskMap[dataTask] as? WKURLSchemeTask, dataTask.state == .running {
                schemeTask.didReceive(response)
            }

        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if #available(iOS 11.0, *) {
            if let schemeTask = taskMap[dataTask] as? WKURLSchemeTask, dataTask.state == .running {
                schemeTask.didReceive(data)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if #available(iOS 11.0, *) {
            if let schemeTask = taskMap[task as! URLSessionDataTask] as? WKURLSchemeTask {
                if let error = error {
                    schemeTask.didFailWithError(error)
                } else {
                    schemeTask.didFinish()
                }
            }

            taskMap.removeValue(forKey: task as! URLSessionDataTask)
        }
    }
}

enum WebKitImageDownloaderError: Error {
    case invalidURL
}

// MARK: - WKURLSchemeHandler
@available(iOS 11.0, *)
extension WebKitImageDownloader: WKURLSchemeHandler {
    @available(iOS 11.0, *)
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        DDLogDebug("start \(urlSchemeTask.request)")
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
        DDLogDebug("stop \(urlSchemeTask.request)")
        stop(schemeTask: urlSchemeTask)
    }
}
