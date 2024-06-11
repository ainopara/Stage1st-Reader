//
//  S1User.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

public final class User: Codable {
    let id: Int
    var name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

extension User {
    var avatarURL: URL? {
        let idString = String(format: "%09d", id)

        let xyz = idString.prefix(3)
        let ab = idString.dropFirst(3).prefix(2)
        let cd = idString.dropFirst(5).prefix(2)
        let ef = idString.dropFirst(7)

        return URL(string: "https://avatar.saraba1st.com/\(xyz)/\(ab)/\(cd)/\(ef)_avatar_middle.jpg")
    }
}
