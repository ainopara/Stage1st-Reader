//
//  CrashlyticsLogger.swift
//  Stage1st
//
//  Created by Zheng Li on 3/6/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack.DDLog
import Crashlytics

class CrashlyticsLogger: DDAbstractLogger {
    static let sharedInstance = {
        return CrashlyticsLogger()
    }()

    override func logMessage(logMessage: DDLogMessage!) {
        var logMsg = logMessage.valueForKey("_message") as? NSString
        if let theLogFormatter = self.valueForKey("_logFormatter") as? DDLogFormatter {
            logMsg = theLogFormatter.formatLogMessage(logMessage)
        }
        if let message = logMsg {
            print("CrashlyticsLogger:\(message)")
        }
    }
}