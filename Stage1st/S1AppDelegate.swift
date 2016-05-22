//
//  S1AppDelegate.swift
//  Stage1st
//
//  Created by Zheng Li on 4/4/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack

// MARK: Migration
extension S1AppDelegate {

    func setLogLevelForSwift() {
        #if DEBUG
            defaultDebugLevel = .Verbose
        #else
            defaultDebugLevel = .Info
        #endif
    }

    func migrate() {

    }
}
