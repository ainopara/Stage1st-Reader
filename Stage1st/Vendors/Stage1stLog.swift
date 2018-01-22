//
//  Stage1stLog.swift
//  Stage1st
//
//  Created by Zheng Li on 16/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack

public func DDLogTracking(_ message: @autoclosure () -> String,
                          level: DDLogLevel = defaultDebugLevel,
                          file: StaticString = #file,
                          function: StaticString = #function,
                          line: UInt = #line,
                          tag: Any? = nil,
                          asynchronous async: Bool = false,
                          ddlog: DDLog = DDLog.sharedInstance) {
    _DDLogMessage(message,
                  level: level,
                  flag: .error,
                  context: 1024,
                  file: file,
                  function: function,
                  line: line,
                  tag: tag,
                  asynchronous: async,
                  ddlog: ddlog)
}
