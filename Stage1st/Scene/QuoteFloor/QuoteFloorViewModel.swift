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

    let centerFloorID: Int
    let baseURL: URL

    init(
        topic: S1Topic,
        floors: [Floor],
        centerFloorID: Int,
        baseURL: URL
    ) {
        self.topic = topic
        self.floors = floors
        self.centerFloorID = centerFloorID
        self.baseURL = baseURL
    }

    func userIsBlocked(with userID: Int) -> Bool {
        return AppEnvironment.current.dataCenter.userIDIsBlocked(ID: userID)
    }
}

// MARK: - View Model

extension QuoteFloorViewModel: UserViewModelMaker {
    func userViewModel(userID: Int) -> UserViewModel {
        let username = floors.first(where: { $0.author.id == userID })?.author.name
        return UserViewModel(
            dataCenter: AppEnvironment.current.dataCenter,
            user: User(id: userID, name: username ?? "")
        )
    }
}

extension QuoteFloorViewModel: ContentViewModelMaker {
    func contentViewModel(topic: S1Topic) -> ContentViewModel {
        return ContentViewModel(topic: topic)
    }
}
