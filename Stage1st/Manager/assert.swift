//
//  assert.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/10/1.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation

func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) {
    if !condition() {
        let error = NSError(domain: ("\(file)" as NSString).lastPathComponent, code: Int(line), userInfo: ["message": message()])
        AppEnvironment.current.eventTracker.recordError(error)
    }

    Swift.assert(condition(), message(), file: file, line: line)
}

func assertionFailure(_ message: @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) {
    let error = NSError(domain: ("\(file)" as NSString).lastPathComponent, code: Int(line), userInfo: ["message": message()])
    AppEnvironment.current.eventTracker.recordError(error)
    Swift.assertionFailure(message(), file: file, line: line)
}
