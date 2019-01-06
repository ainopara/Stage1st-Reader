//
//  StringBoolTransformer.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/11/3.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import CodableExtensions

struct StringBoolTransformer: DecodingContainerTransformer {
    typealias Input = String
    typealias Output = Bool

    func transform(_ decoded: String) throws -> Bool {
        guard let intValue = Int(decoded) else {
            throw "Failed to transform \(decoded) to Int."
        }

        return intValue != 0
    }
}
