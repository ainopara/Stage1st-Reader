//
//  Poll.swift
//  Stage1st
//
//  Created by Zheng Li on 6/16/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

struct RawPollOption: Decodable {
    let id: String
    let name: String
    let votes: String
    let percent: String
    let color: String

    private enum CodingKeys: String, CodingKey {
        case id = "polloptionid"
        case name = "polloption"
        case votes
        case percent
        case color
    }
}

struct RawPoll: Decodable {
    let options: [RawPollOption]
    let expirationDate: String
    let maxChoices: String
    let visible: String
    let allowVote: String
    let remainTime: String
}
