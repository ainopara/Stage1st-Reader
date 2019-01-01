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
        return URL(string: "https://centeru.saraba1st.com/avatar.php?uid=\(id)&size=middle")
    }
}
