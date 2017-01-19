//
//  S1FoundationTests.swift
//  Stage1st
//
//  Created by Zheng Li on 5/28/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import XCTest
@testable import Stage1st

class S1DateFormatterTests: XCTestCase {
    var dateList = [Date]()

    override func setUp() {
        let count = 3000
        let timeRange:UInt32 = 1_000_000

        for _ in 1...count {
            let random: Double = Double(arc4random() % timeRange)
            let date = Date(timeIntervalSinceNow: -random)
            self.dateList.append(date)
        }
    }

    func testFormatterPerformance() {
        self.measure {
            for date in self.dateList {
                _ = date.s1_gracefulDateTimeString()
            }
        }
    }
}
