//
//  Stage1stTests.swift
//  Stage1stTests
//
//  Created by Zheng Li on 5/20/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import XCTest
import KIF
import FBSnapshotTestCase
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
        let data = NSKeyedArchiver.archivedDataWithRootObject(tracedTopic)
        tracedTopic = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? S1Topic

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

        XCTAssert(tracedTopic.title == "server", "should be updated")
        XCTAssert(tracedTopic.replyCount == 2, "should be updated")
        XCTAssert(tracedTopic.lastReplyCount == 1, "should be updated")
        XCTAssert(tracedTopic.authorUserID == 2, "should be updated")
        XCTAssert(tracedTopic.fID == 2, "should be updated")

        XCTAssert(tracedTopic.hasChangedProperties, "should be changed after update")
        XCTAssert(tracedTopic.changedProperties.count == 5, "should be changed after update")
        XCTAssert(tracedTopic.changedCloudProperties.count == 4, "should be changed after update")
    }
    
    func testUpdate2() {
        serverTopic.makeImmutable()
        voidTopic.update(serverTopic)

        XCTAssert(voidTopic.title == "server", "should be updated")
        XCTAssert(voidTopic.replyCount == 2, "should be updated")
        XCTAssert(voidTopic.lastReplyCount == nil, "should be nil")
        XCTAssert(voidTopic.authorUserID == 2, "should be updated")
        XCTAssert(voidTopic.fID == 2, "should be updated")

        XCTAssert(voidTopic.hasChangedProperties, "should be changed after update")
        XCTAssert(voidTopic.changedProperties.count == 5, "should be changed after update")
        XCTAssert(voidTopic.changedCloudProperties.count == 4, "should be changed after update")
    }

    func testUpdate3() {
        voidTopic.makeImmutable()
        tracedTopic.update(voidTopic)

        XCTAssert(tracedTopic.title == "traced", "should not be updated")
        XCTAssert(tracedTopic.changedProperties.count == 1, "should not change any property but lastReplyCount")
        XCTAssert(tracedTopic.changedProperties.contains("lastReplyCount"), "should not change any property but lastReplyCount")
    }
    
    func testPerformanceUpdate() {

        self.measureBlock {

        }
    }
    
}

extension XCTestCase {
    func tester(file : String = #file, _ line : Int = #line) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self)
    }

    func system(file : String = #file, _ line : Int = #line) -> KIFSystemTestActor {
        return KIFSystemTestActor(inFile: file, atLine: line, delegate: self)
    }
}

extension KIFTestActor {
    func tester(file : String = #file, _ line : Int = #line) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self)
    }

    func system(file : String = #file, _ line : Int = #line) -> KIFSystemTestActor {
        return KIFSystemTestActor(inFile: file, atLine: line, delegate: self)
    }
}

class S1UITests: KIFTestCase {
    func testArchive() {
        tester().tapViewWithAccessibilityLabel("Archive", traits: UIAccessibilityTraitButton)
        tester().tapViewWithAccessibilityLabel("Favorite", traits: UIAccessibilityTraitButton)
//        tester().tapViewWithAccessibilityLabel("Search Bar", traits: UIAccessibilityTraitSearchField)
//        tester().waitForKeyInputReady()
        // TODO: Finish this with `FBSnapshotTestCase` and `GYHttpMock`
    }
}

class S1SnapshotTests: FBSnapshotTestCase {

    override func setUp() {
        super.setUp()
//        self.recordMode = true
    }

    func testTabbar1() {
        let tabbar = S1TabBar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        FBSnapshotVerifyView(tabbar, identifier: "s1tabbar-0tab")
    }

    func testTabbar2() {
        let tabbar = S1TabBar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        tabbar.keys = ["a"]
        FBSnapshotVerifyView(tabbar, identifier: "s1tabbar-1tab")
    }

    func testTabbar3() {
        let tabbar = S1TabBar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        tabbar.keys = ["a", "b", "c"]
        FBSnapshotVerifyView(tabbar, identifier: "s1tabbar-3tab")
    }

    func testTabbar4() {
        let tabbar = S1TabBar(frame: CGRect(x: 0, y: 0, width: 450, height: 44))
        tabbar.keys = ["a", "b", "c", "d"]
        FBSnapshotVerifyView(tabbar, identifier: "s1tabbar-4tab-wide")
    }

    func testTabbar5() {
        let tabbar = S1TabBar(frame: CGRect(x: 0, y: 0, width: 450, height: 44))
        tabbar.keys = ["a", "b", "c", "d", "e", "fghijk", "l"]
        FBSnapshotVerifyView(tabbar, identifier: "s1tabbar-7tab-wide")
    }
}
