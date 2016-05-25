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
        var nextFloorID = firstFloorID
        while let floor = self.searchFloorInCache(nextFloorID) {
            result.insert(floor, atIndex: 0)
            if let quoteFloorID = floor.firstQuoteReplyFloorID as? Int {
                nextFloorID = quoteFloorID
            } else {
                return result
            }
        }

        return result
    }

    static func templateBundle() -> NSBundle {
        let templateBundleURL = NSBundle.mainBundle().URLForResource("WebTemplate", withExtension: "bundle")!
        return NSBundle.init(URL: templateBundleURL)!
    }

    static func baseURL() -> NSURL {
        return self.templateBundle().URLForResource("ThreadTemplate", withExtension: "html", subdirectory: "html")!
    }
}
