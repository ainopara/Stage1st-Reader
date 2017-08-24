//
//  FloorViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import TextAttributes
import WebKit
import CocoaLumberjack

final class QuoteFloorViewModel: NSObject, PageRenderer {
    let topic: S1Topic
    let floors: [Floor]

    let dataCenter: DataCenter
    let discuzAPIManager: DiscuzClient

    let centerFloorID: Int
    let baseURL: URL

    init(dataCenter: DataCenter,
         manager: DiscuzClient,
         topic: S1Topic,
         floors: [Floor],
         centerFloorID: Int,
         baseURL: URL) {
        self.dataCenter = dataCenter
        discuzAPIManager = manager
        self.topic = topic
        self.floors = floors
        self.centerFloorID = centerFloorID
        self.baseURL = baseURL
    }

    func userIsBlocked(with userID: UInt) -> Bool {
        return dataCenter.userIDIsBlocked(ID: userID)
    }
}

extension QuoteFloorViewModel: UserViewModelMaker {
    func userViewModel(userID: UInt) -> UserViewModel {
        return UserViewModel(dataCenter: dataCenter,
                             user: User(ID: userID, name: ""))
    }
}

extension QuoteFloorViewModel: ContentViewModelMaker {
    func contentViewModel(topic: S1Topic) -> ContentViewModel {
        return ContentViewModel(topic: topic, dataCenter: dataCenter)
    }
}

// MARK: - WKURLSchemeHandler
@available(iOS 11.0, *)
extension QuoteFloorViewModel: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        DDLogDebug("start \(urlSchemeTask.request)")
        var request = urlSchemeTask.request
        guard let urlString = request.url?.absoluteString else {
            return
        }
        request.url = URL(string: urlString.s1_replace(pattern: "^image", with: "http"))

        AppEnvironment.current.urlSessionManager.start(schemeTask: urlSchemeTask, with: request)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        DDLogDebug("stop \(urlSchemeTask.request)")
        AppEnvironment.current.urlSessionManager.stop(schemeTask: urlSchemeTask)
    }
}
