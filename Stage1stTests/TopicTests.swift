//
//  Stage1stTests.swift
//  Stage1stTests
//
//  Created by Zheng Li on 5/20/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import XCTest
@testable import Stage1st

class S1TopicTests: XCTestCase {
    var voidTopic: S1Topic!
    var tracedTopic: S1Topic!
    var serverTopic: S1Topic!
    
    override func setUp() {
        super.setUp()
        voidTopic = S1Topic(topicID: 100)

        tracedTopic = S1Topic(topicID: 100)
        tracedTopic.title = "traced"
        tracedTopic.replyCount = 1
        tracedTopic.authorUserID = 1
        tracedTopic.fID = 1

        // Reset changed property record
        let data = NSKeyedArchiver.archivedData(withRootObject: tracedTopic)
        tracedTopic = NSKeyedUnarchiver.unarchiveObject(with: data) as? S1Topic

        serverTopic = S1Topic(topicID: 100)
        serverTopic.title = "server"
        serverTopic.replyCount = 2
        serverTopic.authorUserID = 2
        serverTopic.fID = 2

        XCTAssert(tracedTopic != nil, "should not be nil")
        XCTAssert(!tracedTopic.hasChangedProperties, "should not be changed")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testUpdate1() {
        serverTopic.makeImmutable()
        tracedTopic.update(serverTopic)

        XCTAssertEqual(tracedTopic.title, "server", "should be updated")
        XCTAssertEqual(tracedTopic.replyCount, 2, "should be updated")
        XCTAssertEqual(tracedTopic.lastReplyCount, 1, "should be updated")
        XCTAssertEqual(tracedTopic.authorUserID, 2, "should be updated")
        XCTAssertEqual(tracedTopic.fID, 2, "should be updated")

        XCTAssertTrue(tracedTopic.hasChangedProperties, "should be changed after update")
        XCTAssertEqual(tracedTopic.changedProperties.count, 5, "should be 5 changed properties after update, but got \(String(describing: tracedTopic.changedProperties))")
        XCTAssertEqual(tracedTopic.changedCloudProperties.count, 4, "should be changed after update")
    }
    
    func testUpdate2() {
        serverTopic.makeImmutable()
        voidTopic.update(serverTopic)

        XCTAssertEqual(voidTopic.title, "server", "should be updated")
        XCTAssertEqual(voidTopic.replyCount, 2, "should be updated")
        XCTAssertEqual(voidTopic.lastReplyCount, nil, "should be nil")
        XCTAssertEqual(voidTopic.authorUserID, 2, "should be updated")
        XCTAssertEqual(voidTopic.fID, 2, "should be updated")

        XCTAssertTrue(voidTopic.hasChangedProperties, "should be changed after update")
        XCTAssertEqual(voidTopic.changedProperties.count, 5, "should be 5 changed properties after update, but got \(String(describing: voidTopic.changedProperties))")
        XCTAssertEqual(voidTopic.changedCloudProperties.count, 4, "should be changed after update")
    }

    func testUpdate3() {
        voidTopic.makeImmutable()
        tracedTopic.update(voidTopic)

        XCTAssertEqual(tracedTopic.title, "traced", "should not be updated")
        XCTAssertEqual(tracedTopic.changedProperties.count, 1, "should not change any property but lastReplyCount, but got \(String(describing: tracedTopic.changedProperties))")
        XCTAssertTrue(tracedTopic.changedProperties.contains("lastReplyCount"), "should not change any property but lastReplyCount")
    }
}
