//
//  TabBarSnapshotTests.swift
//  Stage1stTests
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation
import FBSnapshotTestCase
@testable import Stage1st

class TabBarSnapshotTests: FBSnapshotTestCase {
    override func setUp() {
        super.setUp()
//        recordMode = true
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
