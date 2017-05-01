//
//  UserViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 5/31/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire
import ReactiveCocoa
import ReactiveSwift

class UserViewModel {
    let dataCenter: DataCenter
    let user: MutableProperty<User>
    let blocked: MutableProperty<Bool>

    init(dataCenter: DataCenter, user: User) {
        self.dataCenter = dataCenter
        self.user = MutableProperty(user)
        blocked = MutableProperty(dataCenter.userIDIsBlocked(ID: user.ID))

        blocked.signal.observeValues { isBlocked in
            if isBlocked {
                dataCenter.blockUser(with: user.ID)
                NotificationCenter.default.post(name: .UserBlockStatusDidChangedNotification, object: nil)
            } else {
                dataCenter.unblockUser(with: user.ID)
                NotificationCenter.default.post(name: .UserBlockStatusDidChangedNotification, object: nil)
            }
        }
    }

    func updateCurrentUserProfile(_ resultBlock: @escaping (Alamofire.Result<User>) -> Void) {
        dataCenter.apiManager.profile(userID: user.value.ID) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case let .success(user):
                strongSelf.user.value = user
                resultBlock(.success(user))
            case let .failure(error):
                resultBlock(.failure(error))
            }
        }
    }

    func infoLabelText() -> String {
        let infoLabelString = NSMutableString()

        if let lastVisitDateString = user.value.lastVisitDateString {
            infoLabelString.append("最后访问：\n\(lastVisitDateString)\n")
        }
        if let registerDateString = user.value.registerDateString {
            infoLabelString.append("注册日期：\n\(registerDateString)\n")
        }
        if let threadCount = user.value.threadCount {
            infoLabelString.append("发帖数：\n\(threadCount)\n")
        }
        if let postCount = user.value.postCount {
            infoLabelString.append("回复数：\n\(postCount)\n")
        }
        if let sigHTML = user.value.sigHTML {
            infoLabelString.append("签名：\n\(sigHTML.s1_htmlStripped(trimWhitespace: false) ?? sigHTML)\n")
        }

        return infoLabelString as String
    }

    var avatarURL: URL? {
        return URL(string: "http://centeru.saraba1st.com/avatar.php?uid=\(user.value.ID)&size=middle")
    }
}

public extension Notification.Name {
    public static let UserBlockStatusDidChangedNotification = Notification.Name.init(rawValue: "UserBlockStatusDidChangedNotification")
}
