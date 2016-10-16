//
//  FloorViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import TextAttributes

final class QuoteFloorViewModel {
    let manager: DiscuzAPIManager
    let topic: S1Topic
    let floors: [Floor]
    let centerFloorID: Int
    let baseURL: URL

    init(manager: DiscuzAPIManager, topic: S1Topic, floors: [Floor], centerFloorID: Int, baseURL: URL) {
        self.manager = manager
        self.topic = topic
        self.floors = floors
        self.centerFloorID = centerFloorID
        self.baseURL = baseURL
    }
}

extension QuoteFloorViewModel: PageRenderer {
}
