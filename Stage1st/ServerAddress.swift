//
//  ServerAddress.swift
//  Stage1st
//
//  Created by Zheng Li on 06/04/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

class ServerAddress: NSObject, NSCoding {
    struct Constants {
        static let mainURLKey = "main"
        static let usedURLsKey = "used"
        static let lastUpdateDateKey = "date"
    }

    let main: String
    let used: [String]
    let lastUpdateDate: Date

    static let `default` = ServerAddress(main: "http://bbs.saraba1st.com/2b", used: [], lastUpdateDate: Date.distantPast)
    static var traced: ServerAddress { return .default }

    init(main: String, used: [String], lastUpdateDate: Date) {
        self.main = main
        self.used = used
        self.lastUpdateDate = lastUpdateDate
    }

    required init?(coder aDecoder: NSCoder) {
        guard let mainURL = aDecoder.decodeObject(forKey: Constants.mainURLKey) as? String,
            let usedURLs = aDecoder.decodeObject(forKey: Constants.usedURLsKey) as? [String],
            let lastUpdateDate = aDecoder.decodeObject(forKey: Constants.lastUpdateDateKey) as? Date else {
            return nil
        }

        main = mainURL
        used = usedURLs
        self.lastUpdateDate = lastUpdateDate
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(main, forKey: Constants.mainURLKey)
        aCoder.encode(used, forKey: Constants.usedURLsKey)
        aCoder.encode(lastUpdateDate, forKey: Constants.lastUpdateDateKey)
    }
}

extension ServerAddress {
    func hasSameDomain(with url: URL) -> Bool {
        for baseURL in [main] + used {
            if url.absoluteString.hasPrefix(baseURL) {
                return true
            }
        }

        return false
    }
}
