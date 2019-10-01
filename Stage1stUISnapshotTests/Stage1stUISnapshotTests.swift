//
//  Stage1stUISnapshotTests.swift
//  Stage1stUISnapshotTests
//
//  Created by Zheng Li on 2019/9/28.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import XCTest

class Stage1stUISnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSnapshot() {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launchEnvironment = ["STAGE1ST_SNAPSHOT_TEST": "true"]
        setupSnapshot(app)
        app.launch()


        app/*@START_MENU_TOKEN@*/.buttons["游戏论坛"]/*[[".scrollViews.buttons[\"游戏论坛\"]",".buttons[\"游戏论坛\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        snapshot("0TopicList")

        app.cells.staticTexts["【怪物猎人世界:冰原】综合讨论帖[DLC发售日2019.09.06]"].tap()

        let exist = NSPredicate(format: "exists == 1")
        let expection = expectation(for: exist, evaluatedWith: app.links["・・・"], handler: nil)
        wait(for: [expection], timeout: 10.0)
        snapshot("1Detail")

        let toolbar = app.toolbars["Toolbar"]
        toolbar.buttons["Share"].tap()
        app.sheets.scrollViews.otherElements.buttons["Reply"].tap()
        toolbar.buttons["MahjongFaceButton"].tap()
        app.cells["[f:033]"].tap()
        snapshot("2Reply")

        app.navigationBars["Reply"].buttons["Cancel"].tap()
        toolbar.buttons["Back"].tap()
        app.navigationBars["Stage1st"].buttons["Archive"].tap()
        snapshot("3Archive")
        app.navigationBars.buttons["Settings"].tap()
        snapshot("4Settings")
    }
}
