//
//  CacheDatabaseManager.swift
//  Stage1st
//
//  Created by Zheng Li on 9/19/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import YapDatabase
import CocoaLumberjack

class CacheDatabaseManager: NSObject {
    static let shared = CacheDatabaseManager()

    override init() {
        super.init()
    }

    func set(floors: [Floor], topicID: Int, page: Int, completion: @escaping () -> Void) {

    }

    func floors(in topicID: Int, page: Int) -> [Floor]? {
        return nil
    }

    func hasFloors(in topicID: Int, page: Int) -> Bool {
        return false
    }

    func removeFloors(in topicID: Int, page: Int) {

    }
}

extension CacheDatabaseManager {
    func floor(ID: Int) -> Floor? {
        return nil
    }
}

extension CacheDatabaseManager {
    func removeFloors(lastUsedBefore date: Date) {

    }
}

extension CacheDatabaseManager {
    func set(mahjongFaceHistory: [String]) {

    }

    func mahjongFaceHistory() -> [String]? {
        return nil
    }
}
