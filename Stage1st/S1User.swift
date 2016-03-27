//
//  S1User.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

class User {
    var ID: Int = 0
    var name: String = ""
    var avatarURL: NSURL? = nil

    init(ID: Int) {
        self.ID = ID
    }

}
