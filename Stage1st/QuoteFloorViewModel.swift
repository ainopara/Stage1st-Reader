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
    let discuzAPIManager: DiscuzAPIManager

    let centerFloorID: Int
    let baseURL: URL

    init(dataCenter: S1DataCenter, manager: DiscuzAPIManager, topic: S1Topic, floors: [Floor], centerFloorID: Int, baseURL: URL) {
        self.dataCenter = dataCenter
        self.discuzAPIManager = manager
        self.topic = topic
        self.floors = floors
        self.centerFloorID = centerFloorID
        self.baseURL = baseURL
    }
}

extension QuoteFloorViewModel: UserViewModelGenerator {
    func userViewModel(userID: Int) -> UserViewModel {
        return UserViewModel(manager: discuzAPIManager,
                             user: User(ID: userID, name: ""))
    }
}
