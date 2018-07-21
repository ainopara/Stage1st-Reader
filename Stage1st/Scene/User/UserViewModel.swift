//
//  UserViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 5/31/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire
import ReactiveSwift

class UserViewModel {
    let dataCenter: DataCenter
    let user: MutableProperty<User>
    let isBlocked: MutableProperty<Bool>

    let avatarURL: MutableProperty<URL?> = MutableProperty(nil)
    let username: MutableProperty<String> = MutableProperty("")

    init(dataCenter: DataCenter, user: User) {
        self.dataCenter = dataCenter
        self.user = MutableProperty(user)
        isBlocked = MutableProperty(dataCenter.userIDIsBlocked(ID: user.ID))

        avatarURL <~ self.user.map { (user) in
            return URL(string: "https://centeru.saraba1st.com/avatar.php?uid=\(user.ID)&size=middle")
        }.skipRepeats()

        username <~ self.user.map({ (user) in
            return user.name
        }).skipRepeats()
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
        var infoLabelString = ""

        if let lastVisitDateString = user.value.lastVisitDateString {
            infoLabelString += "最后访问：\n\(lastVisitDateString)\n"
        }
        if let registerDateString = user.value.registerDateString {
            infoLabelString += "注册日期：\n\(registerDateString)\n"
        }
        if let threadCount = user.value.threadCount {
            infoLabelString += "发帖数：\n\(threadCount)\n"
        }
        if let postCount = user.value.postCount {
            infoLabelString += "回复数：\n\(postCount)\n"
        }
        if let sigHTML = user.value.sigHTML {
            infoLabelString += "签名：\n\(sigHTML.s1_htmlStripped(trimWhitespace: false) ?? sigHTML)\n"
        }

        return infoLabelString
    }

    func toggleBlockStatus() {
        isBlocked.value = !isBlocked.value
        if isBlocked.value {
            dataCenter.blockUser(with: user.value.ID)
        } else {
            dataCenter.unblockUser(with: user.value.ID)
        }
    }
}

public extension Notification.Name {
    public static let UserBlockStatusDidChangedNotification = Notification.Name.init(rawValue: "UserBlockStatusDidChangedNotification")
}
