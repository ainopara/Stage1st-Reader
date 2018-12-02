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
import Result

class UserViewModel {
    let dataCenter: DataCenter
    let user: MutableProperty<User>
    let isBlocked: SignalProducer<Bool, NoError>
    let username: SignalProducer<String, NoError>

    init(dataCenter: DataCenter, user: User) {
        self.dataCenter = dataCenter
        self.user = MutableProperty(user)

        isBlocked = self.user
            .map({ dataCenter.userIDIsBlocked(ID: $0.ID) })
            .producer

        username = self.user
            .map({ $0.name })
            .skipRepeats()
            .producer
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
        let isBlocked = dataCenter.userIDIsBlocked(ID: user.value.ID)
        if isBlocked {
            dataCenter.blockUser(with: user.value.ID)
        } else {
            dataCenter.unblockUser(with: user.value.ID)
        }

        user.value = user.value
    }
}

public extension Notification.Name {
    public static let UserBlockStatusDidChanged = Notification.Name.init(rawValue: "UserBlockStatusDidChanged")
}
