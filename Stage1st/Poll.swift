//
//  Poll.swift
//  Stage1st
//
//  Created by Zheng Li on 6/16/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import JASON

typealias HEXColor = String

class PollOption: NSObject {
    let ID: Int
    let name: String?
    let votes: Int?
    let percent: Double?
    let color: HEXColor?
    let imageInfo: [String]?

    init?(json: JSON) {
        guard let IDString = json["polloptionid"].string, ID = Int(IDString) else {
            return nil
        }
        self.ID = ID
        self.name = json["polloption"].string

        if let votesString = json["votes"].string, votes = Int(votesString) {
            self.votes = votes
        } else {
            self.votes = nil
        }

        if let percentString = json["percent"].string, percent = Double(percentString) {
            self.percent = percent
        } else {
            self.percent = nil
        }

        self.color = json["color"].string

        self.imageInfo = nil // FIXME: Finish this.

        super.init()
    }
}

class Poll: NSObject {
    let options: [PollOption]
    let expirationDate: NSDate?
    let maxChoices: Int?
    let visible: Bool?
    let allowVote: Bool?
    let remainTime: NSTimeInterval?

    init?(json: JSON) {
        guard let optionsDictionary = json["polloptions"].jsonDictionary else { return nil }
        self.options = optionsDictionary.values.flatMap { (json) -> PollOption? in
            return PollOption(json: json)
        }

        guard self.options.count != 0 else {
            return nil
        }

        if let expirationString = json["expirations"].string, expirationSeconds = Double(expirationString) {
            self.expirationDate = NSDate(timeIntervalSince1970: expirationSeconds)
        } else {
            self.expirationDate = nil
        }

        if let maxChoicesString = json["maxchoices"].string, maxChoices = Int(maxChoicesString) {
            self.maxChoices = maxChoices
        } else {
            self.maxChoices = nil
        }

        if let visibleString = json["visiblepool"].string, visibleInt = Int(visibleString) {
            self.visible = visibleInt == 0 ? false : true
        } else {
            self.visible = nil
        }

        if let allowVoteString = json["allowvote"].string, allowVoteInt = Int(allowVoteString) {
            self.allowVote = allowVoteInt == 0 ? false : true
        } else {
            self.allowVote = nil
        }

        // FIXME: check this api.
        if let remainTimeString = json["remaintime"].string, remainTimeSeconds = Double(remainTimeString) {
            self.remainTime = remainTimeSeconds
        } else {
            self.remainTime = nil
        }

        super.init()
    }
}
