//
//  Field.swift
//  Stage1st
//
//  Created by Zheng Li on 09/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct Field {
    let ID: UInt
    let name: String
    let threadCounts: UInt
    let postCounts: UInt
    let rules: String

    init?(json: JSON) {
        guard let ID = json["forum"]["fid"].string.flatMap({ UInt($0) }),
            let name = json["forum"]["name"].string,
            let threadCounts = json["forum"]["threads"].string.flatMap({ UInt($0) }),
            let postCounts = json["forum"]["posts"].string.flatMap({ UInt($0) }),
            let rules = json["forum"]["rules"].string else {
            return nil
        }

        self.ID = ID
        self.name = name
        self.threadCounts = threadCounts
        self.postCounts = postCounts
        self.rules = rules
    }
}
