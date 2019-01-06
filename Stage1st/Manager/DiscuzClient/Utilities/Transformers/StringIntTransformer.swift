//
//  StringIntTransformer.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/21.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation
import CodableExtensions

struct StringIntTransformer: DecodingContainerTransformer {
    typealias Input = String
    typealias Output = Int

    func transform(_ decoded: String) throws -> Int {
        guard let intValue = Int(decoded) else {
            throw "Failed to transform \(decoded) to Int."
        }

        return intValue
    }
}
