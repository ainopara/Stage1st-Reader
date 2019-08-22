//
//  UserViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 5/31/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire
import RxSwift
import RxRelay

class UserViewModel {
    let dataCenter: DataCenter
    let user: BehaviorRelay<User>
    let isBlocked = BehaviorRelay<Bool>(value: false)
    let username = BehaviorRelay<String>(value: "")

    let bag = DisposeBag()

    static let userBlockStatusDidChangeNotification = Notification.Name(rawValue: "UserViewModel.userBlockStatusDidChangeNotification")

    init(dataCenter: DataCenter, user: User) {
        self.dataCenter = dataCenter
        self.user = BehaviorRelay(value: user)

        self.user
            .map { dataCenter.userIDIsBlocked(ID: $0.id) }
            .bind(to: isBlocked)
            .disposed(by: bag)

        self.user
            .map { $0.name }
            .distinctUntilChanged()
            .bind(to: username)
            .disposed(by: bag)
    }

    func updateCurrentUserProfile(_ resultBlock: @escaping (Result<User, Error>) -> Void) {
        dataCenter.apiManager.profile(userID: user.value.id) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case let .success(user):
                strongSelf.user.accept(user)
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

        user.accept(user.value)
    }
}
