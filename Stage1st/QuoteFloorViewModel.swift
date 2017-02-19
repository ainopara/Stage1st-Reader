//
//  FloorViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import TextAttributes

final class QuoteFloorViewModel: PageRenderer {
    let topic: S1Topic
    let floors: [Floor]

    let dataCenter: S1DataCenter
    let discuzAPIManager: DiscuzClient

    let centerFloorID: Int
    let baseURL: URL

    init(dataCenter: S1DataCenter,
         manager: DiscuzClient,
         topic: S1Topic,
         floors: [Floor],
         centerFloorID: Int,
         baseURL: URL) {
        self.dataCenter = dataCenter
        self.discuzAPIManager = manager
        self.topic = topic
        self.floors = floors
        self.centerFloorID = centerFloorID
        self.baseURL = baseURL
    }

    func userIsBlocked(with userID: UInt) -> Bool {
        return dataCenter.userIDIsBlocked(userID)
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
