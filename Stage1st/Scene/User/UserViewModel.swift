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
            .map({ dataCenter.userIDIsBlocked(ID: $0.id) })
            .producer

        username = self.user
            .map({ $0.name })
            .skipRepeats()
            .producer
    }

    func updateCurrentUserProfile(_ resultBlock: @escaping (Alamofire.Result<User>) -> Void) {
        dataCenter.apiManager.profile(userID: user.value.id) { [weak self] result in
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

    func toggleBlockStatus() {
        let isBlocked = dataCenter.userIDIsBlocked(ID: user.value.id)
        if isBlocked {
            dataCenter.unblockUser(with: user.value.id)
        } else {
            dataCenter.blockUser(with: user.value.id)
        }

        user.value = user.value
    }
}

public extension Notification.Name {
    static let UserBlockStatusDidChanged = Notification.Name.init(rawValue: "UserBlockStatusDidChanged")
}
