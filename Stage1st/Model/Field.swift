//
//  Field.swift
//  Stage1st
//
//  Created by Zheng Li on 09/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct Field: Codable {
    let id: Int
    let name: String
    let threadCount: Int
    let postCount: Int
    let rules: String?

    init?(json: JSON) {
        guard
            let id = json["forum"]["fid"].string.flatMap({ Int($0) }),
            let name = json["forum"]["name"].string,
            let threadCount = json["forum"]["threads"].string.flatMap({ Int($0) }),
            let postCount = json["forum"]["posts"].string.flatMap({ Int($0) })
        else {
            return nil
        }

        self.id = id
        self.name = name
        self.threadCount = threadCount
        self.postCount = postCount
        self.rules = json["forum"]["rules"].string
    }
}
