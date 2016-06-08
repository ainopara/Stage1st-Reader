//
//  UserViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 5/31/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire
//import ReactiveCocoa

class S1UserViewModel {
    private(set) var user: User
    private let apiManager = DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b") // FIXME: base URL should not be hard coded.

    init(user: User) {
        self.user = user
    }

    func updateCurrentUserProfile(resultBlock: (Alamofire.Result<User, NSError>) -> Void) {
        apiManager.profile(self.user.ID) { [weak self] (result) in
            guard let strongSelf = self else { return }
            switch result {
            case .Success(let user):
                strongSelf.user = user
                resultBlock(.Success(user))
            case .Failure(let error):
                resultBlock(.Failure(error))
            }
        }
    }

    func infoLabelAttributedText() -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        if let lastVisitDateString = user.lastVisitDateString {
            attributedString.appendAttributedString(NSAttributedString(string: "最后访问：\n\(lastVisitDateString)\n"))
        }
        if let registerDateString = user.registerDateString {
            attributedString.appendAttributedString(NSAttributedString(string: "注册日期：\n\(registerDateString)\n"))
        }
        if let threadCount = user.threadCount {
            attributedString.appendAttributedString(NSAttributedString(string: "发帖数：\n\(threadCount)\n"))
        }
        if let postCount = user.postCount {
            attributedString.appendAttributedString(NSAttributedString(string: "回复数：\n\(postCount)\n"))
        }
        if let sigHTML = user.sigHTML {
            attributedString.appendAttributedString(NSAttributedString(string: "签名：\n\(sigHTML)\n"))
        }
        return attributedString
    }
}
