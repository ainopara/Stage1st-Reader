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
    var dateList = [NSDate]()

    override func setUp() {
        let count = 3000
        let timeRange:UInt32 = 1_000_000

        for _ in 1...count {
            let random: Double = Double(arc4random() % timeRange)
            let date = NSDate(timeIntervalSinceNow: -random)
            self.dateList.append(date)
        }
    }

    func testFormatter() {
        for timeRange: UInt32 in [100_000, 60_000_000] {
            for _ in 1...10000 {
                let random: Double = Double(arc4random() % timeRange)
                let date = NSDate(timeIntervalSinceNow: -random)
                let stringVersion1 = date.s1_gracefulDateTimeString()
                let stringVersion2 = S1ContentViewModel.translateDateTimeString(date)
                XCTAssert(stringVersion1 == stringVersion2, "\(stringVersion1) != \(stringVersion2)")
            }
        }
    }

    func testFormatterPerformance() {
        self.measureBlock {
            for date in self.dateList {
                date.s1_gracefulDateTimeString()
            }
        }
    }

    func testOldFormatterPerformance() {
        self.measureBlock {
            for date in self.dateList {
                S1ContentViewModel.translateDateTimeString(date)
            }
        }
    }
}
