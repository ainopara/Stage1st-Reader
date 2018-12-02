//
//  RawMessage.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/11/3.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation

public struct RawMessage: Codable {
    let key: String
    let description: String
    private enum CodingKeys: String, CodingKey {
        case key = "messageval"
        case description = "messagestr"
    }
}
