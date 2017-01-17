//
//  MahjongFaceItem.swift
//  Stage1st
//
//  Created by Zheng Li on 10/2/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

private let kKey = "Key"
private let kCategory = "Category"
private let kURL = "URL"

class MahjongFaceItem: NSObject, NSCoding {
    let key: String
    let category: String
    let url: URL

    init(key: String, category: String, url: URL) {
        self.key = key
        self.category = category
        self.url = url
    }

    required init?(coder aDecoder: NSCoder) {
        guard
            let key = aDecoder.decodeObject(forKey: kKey) as? String,
            let category = aDecoder.decodeObject(forKey: kCategory) as? String,
            let url = aDecoder.decodeObject(forKey: kURL) as? URL else {
            return nil
        }

        self.key = key
        self.category = category
        self.url = url
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.key, forKey: kKey)
        aCoder.encode(self.category, forKey: kCategory)
        aCoder.encode(self.url, forKey: kURL)
    }
}
