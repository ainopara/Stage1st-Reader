//
//  Stage1stLog.swift
//  Stage1st
//
//  Created by Zheng Li on 16/02/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import CocoaLumberjack
import Ainoaibo
import os

var asynchronousLogging: Bool = false

enum LogCategory: String, OSLoggerIndexable {
    case `default`

    /// Record network request sended by default network manager.
    case network

    /// Record user input.
    case interaction

    /// Record
    case environment

    /// Record log generated by our extension on UIKit / Foundation class.
    case `extension`

    /// Record UI changes.
    case ui

    /// Record auth state information.
    case auth

    case cloudkit

    var description: String {
        return self.rawValue
    }

    var loggerIndex: String {
        return description
    }
}

enum LogSubsystem: OSLoggerIndexable {
    case `default`
    case file(StaticString)

    var description: String {
        switch self {
        case .default:
            return "stage1st.default"
        case .file(let path):
            let pathString = path.description
            let lastComponent = pathString.split(separator: "/").last ?? ""
            let name = lastComponent.split(separator: ".").first ?? "unknown"
            return String(name)
        }
    }

    var loggerIndex: String {
        return description
    }
}

class S1LoggerTag: OSLoggerTag {
    let subsystem: LogSubsystem
    let category: LogCategory
    let dso: UnsafeRawPointer

    var rawSubsystem: OSLoggerIndexable { return subsystem }
    var rawCategory: OSLoggerIndexable { return category }

    init(subsystem: LogSubsystem, category: LogCategory, dso: UnsafeRawPointer) {
        self.subsystem = subsystem
        self.category = category
        self.dso = dso
    }
}

extension OSLog {
    convenience init(subsystem: LogSubsystem, category: LogCategory) {
        self.init(subsystem: subsystem.description, category: category.description)
    }
}

func S1LogDebug(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    dso: UnsafeRawPointer = #dsohandle,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    category: LogCategory = .default,
    asynchronous async: Bool = asynchronousLogging,
    ddlog: DDLog = DDLog.sharedInstance
) {
    _DDLogMessage(
        message(),
        level: level,
        flag: .debug,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: S1LoggerTag(subsystem: .file(file), category: category, dso: dso),
        asynchronous: async,
        ddlog: ddlog
    )
}

func S1LogInfo(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    dso: UnsafeRawPointer = #dsohandle,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    category: LogCategory = .default,
    asynchronous async: Bool = asynchronousLogging,
    ddlog: DDLog = DDLog.sharedInstance
) {
    _DDLogMessage(
        message(),
        level: level,
        flag: .info,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: S1LoggerTag(subsystem: .file(file), category: category, dso: dso),
        asynchronous: async,
        ddlog: ddlog
    )
}

func S1LogWarn(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    dso: UnsafeRawPointer = #dsohandle,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    category: LogCategory = .default,
    asynchronous async: Bool = asynchronousLogging,
    ddlog: DDLog = DDLog.sharedInstance
) {
    _DDLogMessage(
        message(),
        level: level,
        flag: .warning,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: S1LoggerTag(subsystem: .file(file), category: category, dso: dso),
        asynchronous: async,
        ddlog: ddlog
    )
}

func S1LogVerbose(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    dso: UnsafeRawPointer = #dsohandle,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    category: LogCategory = .default,
    asynchronous async: Bool = asynchronousLogging,
    ddlog: DDLog = DDLog.sharedInstance
) {
    _DDLogMessage(
        message(),
        level: level,
        flag: .verbose,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: S1LoggerTag(subsystem: .file(file), category: category, dso: dso),
        asynchronous: async,
        ddlog: ddlog
    )
}

func S1LogError(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    dso: UnsafeRawPointer = #dsohandle,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    category: LogCategory = .default,
    asynchronous async: Bool = false,
    ddlog: DDLog = DDLog.sharedInstance
) {
    _DDLogMessage(
        message(),
        level: level,
        flag: .error,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: S1LoggerTag(subsystem: .file(file), category: category, dso: dso),
        asynchronous: async,
        ddlog: ddlog
    )
}

public func DDLogTracking(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    tag: Any? = nil,
    asynchronous async: Bool = false,
    ddlog: DDLog = DDLog.sharedInstance
) {
    _DDLogMessage(
        message(),
        level: level,
        flag: .error,
        context: 1024,
        file: file,
        function: function,
        line: line,
        tag: tag,
        asynchronous: async,
        ddlog: ddlog
    )
}

func S1FatalError(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = dynamicLogLevel,
    context: Int = 0,
    dso: UnsafeRawPointer = #dsohandle,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    category: LogCategory = .default,
    asynchronous async: Bool = false,
    ddlog: DDLog = DDLog.sharedInstance
) -> Never {
    _DDLogMessage(
        message(),
        level: level,
        flag: .error,
        context: context,
        file: file,
        function: function,
        line: line,
        tag: S1LoggerTag(subsystem: .file(file), category: category, dso: dso),
        asynchronous: async,
        ddlog: ddlog
    )

    fatalError(message(), file: file, line: line)
}
