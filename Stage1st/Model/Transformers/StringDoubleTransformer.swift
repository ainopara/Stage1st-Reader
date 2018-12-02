//
//  StringDoubleTransformer.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/21.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation
import CodableExtensions

struct StringDoubleTransformer: DecodingContainerTransformer {
    typealias Input = String
    typealias Output = Double

    func transform(_ decoded: String) throws -> Double {
        guard let doubleValue = Double(decoded) else {
            throw "Failed to transform \(decoded) to Double."
        }

        return doubleValue
    }
}
