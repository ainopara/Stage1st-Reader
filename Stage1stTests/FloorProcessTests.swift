//
//  FloorProcessTests.swift
//  Stage1stTests
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation
@testable import Stage1st
import SnapshotTesting

class FloorProcessTests: XCTestCase {

    func testProcessInlineAttachmentImage() {
        /// TopicID: 1637906 Floor: 32
        let rawPost = RawFloorList.Variables.Post()
        let floor = Floor(rawPost: rawPost)
    }
}
