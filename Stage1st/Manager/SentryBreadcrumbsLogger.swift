//
//  SentryBreadcrumbsLogger.swift
//  Stage1st
//
//  Created by Zheng Li on 2020/2/9.
//  Copyright © 2020 Renaissance. All rights reserved.
//

import CocoaLumberjack
import Sentry

private extension DDLoggerName {
    static let sentryBreadcrumbs = DDLoggerName("com.ainopara.sentryBreadcrumbsLogger")
}

class SentryBreadcrumbsLogger: DDAbstractLogger {

    @objc public static let shared = SentryBreadcrumbsLogger()

    override var loggerName: DDLoggerName {
        return .sentryBreadcrumbs
    }

    override func log(message logMessage: DDLogMessage) {
        let message: String?
        if let formatter = value(forKey: "_logFormatter") as? DDLogFormatter {
            message = formatter.format(message: logMessage)
        } else {
            message = logMessage.message
        }

        guard let finalMessage = message else {
            // Log Formatter decided to drop this message.
            return
        }

        let level: SentryLevel = {
            switch logMessage.level {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .warning
            case .error: return .error
            default: return .debug
            }
        }()

        let rawCategory = (logMessage.tag as? S1LoggerTag)?.category.description ?? "default"

        let category: String = "log / \(rawCategory)"
        let breadcrumb = Breadcrumb(level: level, category: category)
        breadcrumb.message = finalMessage
        breadcrumb.timestamp = logMessage.timestamp
        breadcrumb.level = level
        SentrySDK.addBreadcrumb(crumb: breadcrumb)
    }
}
