//
//  DataCenter.swift
//  Stage1st
//
//  Created by Zheng Li on 2/11/17.
//  Copyright © 2017 Renaissance. All rights reserved.
//

extension S1DataCenter {
    func hasPrecachedFloors(for topicID: Int, page: UInt) -> Bool {
        return cacheDatabaseManager.hasFloors(in: topicID, page: Int(page))
    }

    func hasFullPrecachedFloors(for topicID: Int, page: UInt) -> Bool {
        guard let floors = cacheDatabaseManager.floors(in: topicID, page: Int(page)), floors.count >= 30 else {
            return false
        }

        return true
    }
}
