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
    let dataCenter: S1DataCenter
    let user: MutableProperty<User>
    let blocked: MutableProperty<Bool>

    init(dataCenter: S1DataCenter, user: User) {
        self.dataCenter = dataCenter
        self.user = MutableProperty(user)
        self.blocked = MutableProperty(dataCenter.userIDIsBlocked(user.ID))

        blocked.producer.startWithValues { (isBlocked) in
            if isBlocked {
                dataCenter.blockUser(withID: user.ID)
            } else {
                dataCenter.unblockUser(withID: user.ID)
            }
        }
    }

    func updateCurrentUserProfile(_ resultBlock: @escaping (Alamofire.Result<User>) -> Void) {
        dataCenter.apiManager.profile(self.user.value.ID) { [weak self] (result) in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let user):
                strongSelf.user.value = user
                resultBlock(.success(user))
            case .failure(let error):
                resultBlock(.failure(error))
            }
        }
    }

    func infoLabelAttributedText() -> NSAttributedString {
        let attributedString = NSMutableAttributedString()

        if let lastVisitDateString = user.value.lastVisitDateString {
            attributedString.append(NSAttributedString(string: "最后访问：\n\(lastVisitDateString)\n"))
        }
        if let registerDateString = user.value.registerDateString {
            attributedString.append(NSAttributedString(string: "注册日期：\n\(registerDateString)\n"))
        }
        if let threadCount = user.value.threadCount {
            attributedString.append(NSAttributedString(string: "发帖数：\n\(threadCount)\n"))
        }
        if let postCount = user.value.postCount {
            attributedString.append(NSAttributedString(string: "回复数：\n\(postCount)\n"))
        }
        if let sigHTML = user.value.sigHTML {
            attributedString.append(NSAttributedString(string: "签名：\n\(sigHTML)\n"))
        }

        return attributedString
    }
}
