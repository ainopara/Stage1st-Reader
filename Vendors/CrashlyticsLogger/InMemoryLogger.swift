//
//  InMemoryLogger.swift
//  Stage1st
//
//  Created by Zheng Li on 1/25/17.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import UIKit
import CocoaLumberjack

public class InMemoryLogger: DDAbstractLogger {
    @objc public static let shared = InMemoryLogger()
    public var maxMessageEntity = 1000
    public override var loggerName: String { return "com.ainopara.inMemoryLogger" }

    public var messageQueue: [String] { return _messageQueue }
    private var _messageQueue: [String] = []

    public override func log(message logMessage: DDLogMessage) {
        if let logFormatter = self.value(forKey: "_logFormatter") as? DDLogFormatter {
            _messageQueue.append(logFormatter.format(message: logMessage)!)
        } else {
            _messageQueue.append(logMessage.message)
        }

        while _messageQueue.count > maxMessageEntity {
            _messageQueue.removeFirst()
        }
    }
}
