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
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchEnvironment = ["STAGE1ST_SNAPSHOT_TEST": "true"]
        setupSnapshot(app)
        app.launch()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSnapshot() {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        app/*@START_MENU_TOKEN@*/.buttons["动漫论坛"]/*[[".scrollViews.buttons[\"动漫论坛\"]",".buttons[\"动漫论坛\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        snapshot("1-TopicList")

        let stage1stNavigationBar = app.navigationBars["Stage1st"]
        stage1stNavigationBar.buttons["Settings"].tap()
        snapshot("2-Settings")

        app.navigationBars["Settings"].buttons["Back"].tap()
        stage1stNavigationBar.buttons["Archive"].tap()
        snapshot("3-Archive")

        app.tables/*@START_MENU_TOKEN@*/.staticTexts["真·中华一番 动画化"]/*[[".cells.staticTexts[\"真·中华一番 动画化\"]",".staticTexts[\"真·中华一番 动画化\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        snapshot("4-Detail")

        app.toolbars["Toolbar"].buttons["Share"].tap()
        app.sheets.scrollViews.otherElements.buttons["Reply"].tap()
        app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element(boundBy: 1).tap()
        snapshot("5-Reply")
    }

    func testLaunchPerformance() {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTOSSignpostMetric.applicationLaunch]) {
                XCUIApplication().launch()
            }
        }
    }
}
