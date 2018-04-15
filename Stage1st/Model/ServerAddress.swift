//
//  ServerAddress.swift
//  Stage1st
//
//  Created by Zheng Li on 06/04/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import CocoaLumberjack

class ServerAddress: NSObject, NSCoding {
    struct Constants {
        static let mainURLKey = "main"
        static let usedURLsKey = "used"
        static let apiURLKey = "api"
        static let pageURLKey = "page"
        static let lastUpdateDateKey = "date"
    }

    /// HTTP share / original page should use this domain.
    let main: String

    /// HTTP page requests should use this domain.
    let page: String

    /// Discuz! API requests should sent to this domain.
    let api: String

    /// Used to recognize topic URLs of current forum.
    let used: [String]

    /// Used to find out latest server address data.
    let lastUpdateDate: Date

    static let `default` = ServerAddress(
        main: "https://bbs.saraba1st.com/2b",
        page: "https://bbs.saraba1st.com/2b",
        api: "https://bbs.saraba1st.com/2b",
        used: [
            "http://bbs.saraba1st.com",
            "http://www.stage1st.com",
            "http://bbs.stage1.cc",
            "http://119.23.22.79",
            "https://bbs.saraba1st.com",
        ],
        lastUpdateDate: DateComponents(
            calendar: Calendar.current,
            year: 2017,
            month: 9,
            day: 21,
            hour: 8,
            minute: 0,
            second: 0,
            nanosecond: 0
        ).date ?? Date.distantPast
    )

    init(main: String, page: String, api: String, used: [String], lastUpdateDate: Date) {
        self.main = main
        self.page = page
        self.api = api
        self.used = used
        self.lastUpdateDate = lastUpdateDate
    }

    init?(record: CKRecord) {
        guard let mainURL = record["mainURL"] as? String else {
            DDLogError("No mainURL in \(record)")
            return nil
        }

        self.main = mainURL
        self.page = record["pageURL"] as? String ?? mainURL
        self.api = record["apiURL"] as? String ?? mainURL
        self.used = record["usedURLs"] as? [String] ?? [String]()
        self.lastUpdateDate = record.modificationDate ?? Date.distantPast
    }

    required init?(coder aDecoder: NSCoder) {
        guard
            let mainURL = aDecoder.decodeObject(forKey: Constants.mainURLKey) as? String,
            let pageURL = aDecoder.decodeObject(forKey: Constants.pageURLKey) as? String,
            let apiURL = aDecoder.decodeObject(forKey: Constants.apiURLKey) as? String,
            let usedURLs = aDecoder.decodeObject(forKey: Constants.usedURLsKey) as? [String],
            let lastUpdateDate = aDecoder.decodeObject(forKey: Constants.lastUpdateDateKey) as? Date
        else {
            return nil
        }

        main = mainURL
        page = pageURL
        api = apiURL
        used = usedURLs
        self.lastUpdateDate = lastUpdateDate
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(main, forKey: Constants.mainURLKey)
        aCoder.encode(page, forKey: Constants.pageURLKey)
        aCoder.encode(api, forKey: Constants.apiURLKey)
        aCoder.encode(used, forKey: Constants.usedURLsKey)
        aCoder.encode(lastUpdateDate, forKey: Constants.lastUpdateDateKey)
    }

    override var description: String {
        return super.description + """

        main: \(main)
        page: \(page)
        api: \(api)
        used: \(used)
        lastUpdateDate: \(lastUpdateDate)
        """
    }
}

extension ServerAddress {
    func hasSameDomain(with url: URL) -> Bool {
        for baseURL in [main, page, api] + used {
            if url.absoluteString.hasPrefix(baseURL) {
                return true
            }
        }

        return false
    }

    func isPrefered(to serverAddress: ServerAddress) -> Bool {
        return lastUpdateDate.s1_isLaterThan(date: serverAddress.lastUpdateDate)
    }
}
