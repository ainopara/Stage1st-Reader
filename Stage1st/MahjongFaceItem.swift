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
private let kPath = "Path"

class MahjongFaceItem: NSObject, NSCoding {
    let key: String
    let category: String
    let path: String

    var url: URL {
        let baseURL = Bundle.main.bundleURL.appendingPathComponent("Mahjong", isDirectory: true)
        return baseURL.appendingPathComponent(path)
    }

    init?(dictionary: [String: Any], category: String) {
        guard
            let id = dictionary["id"] as? String,
            let path = dictionary["path"] as? String else {
            return nil
        }

        key = id
        self.category = category
        self.path = path

        super.init()
    }

    init(key: String, category: String, path: String) {
        self.key = key
        self.category = category
        self.path = path
    }

    required init?(coder aDecoder: NSCoder) {
        guard
            let key = aDecoder.decodeObject(forKey: kKey) as? String,
            let category = aDecoder.decodeObject(forKey: kCategory) as? String,
            let path = aDecoder.decodeObject(forKey: kPath) as? String else {
            return nil
        }

        self.key = key
        self.category = category
        self.path = path
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(key, forKey: kKey)
        aCoder.encode(category, forKey: kCategory)
        aCoder.encode(path, forKey: kPath)
    }
}
