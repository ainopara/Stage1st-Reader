//
//  S1ContentViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

extension S1ContentViewModel {

    func searchFloorInCache(floorID: Int) -> S1Floor? {
        guard floorID != 0 else {
            return nil
        }

        return self.dataCenter.searchFloorInCacheByFloorID(floorID)
    }

    func chainSearchQuoteFloorInCache(firstFloorID: Int) -> [S1Floor] {
        var result: [S1Floor] = []
        var floor = self.searchFloorInCache(firstFloorID)
        while floor != nil {
            result.insert(floor!, atIndex: 0)
            let firstQuoteFloorID: NSNumber! = floor!.firstQuoteReplyFloorID
            if firstQuoteFloorID == nil {
                break
            }
            floor = self.searchFloorInCache(firstQuoteFloorID as Int)
        }
        return result
    }
}
