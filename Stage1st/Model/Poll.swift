//
//  Poll.swift
//  Stage1st
//
//  Created by Zheng Li on 6/16/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import SwiftyJSON

typealias HEXColor = String

class PollOption: NSObject {
    let ID: Int
    let name: String?
    let votes: Int?
    let percent: Double?
    let color: HEXColor?
    let imageInfo: [String]?

    init?(json: JSON) {
        guard let IDString = json["polloptionid"].string, let ID = Int(IDString) else {
            return nil
        }
        self.ID = ID
        name = json["polloption"].string

        if let votesString = json["votes"].string, let votes = Int(votesString) {
            self.votes = votes
        } else {
            votes = nil
        }

        if let percentString = json["percent"].string, let percent = Double(percentString) {
            self.percent = percent
        } else {
            percent = nil
        }

        color = json["color"].string

        imageInfo = nil // FIXME: Finish this.

        super.init()
    }
}

class Poll: NSObject {
    let options: [PollOption]
    let expirationDate: Date?
    let maxChoices: Int?
    let visible: Bool?
    let allowVote: Bool?
    let remainTime: TimeInterval?

    init?(json: JSON) {
        guard let optionsDictionary = json["polloptions"].dictionary else { return nil }
        options = optionsDictionary.values.compactMap { (json) -> PollOption? in
            return PollOption(json: json)
        }

        guard options.count != 0 else {
            return nil
        }

        if let expirationString = json["expirations"].string, let expirationSeconds = Double(expirationString) {
            expirationDate = Date(timeIntervalSince1970: expirationSeconds)
        } else {
            expirationDate = nil
        }

        if let maxChoicesString = json["maxchoices"].string, let maxChoices = Int(maxChoicesString) {
            self.maxChoices = maxChoices
        } else {
            maxChoices = nil
        }

        if let visibleString = json["visiblepool"].string, let visibleInt = Int(visibleString) {
            visible = visibleInt == 0 ? false : true
        } else {
            visible = nil
        }

        if let allowVoteString = json["allowvote"].string, let allowVoteInt = Int(allowVoteString) {
            allowVote = allowVoteInt == 0 ? false : true
        } else {
            allowVote = nil
        }

        // FIXME: check this api.
        if let remainTimeString = json["remaintime"].string, let remainTimeSeconds = Double(remainTimeString) {
            remainTime = remainTimeSeconds
        } else {
            remainTime = nil
        }

        super.init()
    }
}
