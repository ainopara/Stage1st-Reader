//
//  MahjongFaceCategory.swift
//  Stage1st
//
//  Created by Zheng Li on 16/04/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import UIKit

class MahjongFaceCategory: NSObject {
    let id: String
    let name: String
    let content: [MahjongFaceItem]

    init(id: String, name: String, content: [MahjongFaceItem]) {
        self.id = id
        self.name = name
        self.content = content

        super.init()
    }

    init?(dictionary: [String: Any]) {
        guard
            let id = dictionary["id"] as? String,
            let name = dictionary["name"] as? String,
            let content = dictionary["content"] as? [[String: Any]] else {
            return nil
        }

        self.id = id
        self.name = name
        self.content = content.flatMap { MahjongFaceItem(dictionary: $0, category: id) }

        super.init()
    }
}
