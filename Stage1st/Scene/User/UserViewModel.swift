//
//  UserViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 5/31/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire
import Combine

class UserViewModel {
    private var dataCenter: DataCenter { AppEnvironment.current.dataCenter }

    let user: CurrentValueSubject<User, Never>
    let isBlocked = CurrentValueSubject<Bool, Never>(false)
    let username = CurrentValueSubject<String, Never>("")

    var bag = Set<AnyCancellable>()

    static let userBlockStatusDidChangeNotification = Notification.Name(rawValue: "UserViewModel.userBlockStatusDidChangeNotification")

    init(user: User) {
        self.user = CurrentValueSubject(user)

        self.user
            .map { [weak self] in self?.dataCenter.userIDIsBlocked(ID: $0.id) ?? false }
            .subscribe(isBlocked)
            .store(in: &bag)

        self.user
            .map { $0.name }
            .removeDuplicates()
            .subscribe(username)
            .store(in: &bag)
    }

    func updateCurrentUserProfile(_ resultBlock: @escaping (Result<User, Error>) -> Void) {
        dataCenter.apiManager.profile(userID: user.value.id) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case let .success(user):
                strongSelf.user.send(user)
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

        // FIXME: Remove this workaround which trigger isBlocked recalculation.
        user.send(user.value)
    }
}
