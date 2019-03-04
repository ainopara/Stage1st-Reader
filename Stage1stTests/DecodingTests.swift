//
//  DecodingTests.swift
//  Stage1stTests
//
//  Created by Zheng Li on 2019/3/4.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation
import XCTest
@testable import Stage1st

class Fixture {

    func data(path: String) -> Data {
        let testBundle = Bundle(for: type(of:self))
        let fixturesURL = testBundle.url(forResource: "Fixtures", withExtension: nil)!
        let resourcePath = fixturesURL.appendingPathComponent(path)
        return try! Data(contentsOf: resourcePath)
    }
}

class DecodingTests: XCTestCase {

    func testDecodingTopicList1() throws {
        do {
            let data = Fixture().data(path: "TopicListDecoding/1.json")
            let _ = try JSONDecoder().decode(RawTopicList.self, from: data)
        } catch {
            XCTAssert(false, "\(error)")
        }
    }

    func testDecodingTopicList2() throws {
        do {
            let data = Fixture().data(path: "TopicListDecoding/2.json")
            let _ = try JSONDecoder().decode(RawTopicList.self, from: data)
        } catch {
            XCTAssert(false, "\(error)")
        }
    }

    func testDecodingFloorList1() throws {
        do {
            let data = Fixture().data(path: "FloorListDecoding/1.json")
            let _ = try JSONDecoder().decode(RawFloorList.self, from: data)
        } catch {
            XCTAssert(false, "\(error)")
        }
    }

    func testDecodingFloorList2() throws {
        do {
            let data = Fixture().data(path: "FloorListDecoding/2.json")
            let _ = try JSONDecoder().decode(RawFloorList.self, from: data)
            XCTAssert(false, "This test case expected to failed to decode.")
        } catch {
            XCTAssert(true, "")
        }
    }
}
