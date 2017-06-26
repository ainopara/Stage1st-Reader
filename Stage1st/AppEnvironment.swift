//
//  AppEnvironment.swift
//  Stage1st
//
//  Created by Zheng Li on 13/03/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import Foundation

#if swift(>=4.0)
@objcMembers
#endif
class AppEnvironment: NSObject {
    static var current: Environment = Environment()
}
