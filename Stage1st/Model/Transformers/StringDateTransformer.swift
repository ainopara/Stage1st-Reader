//
//  StringDateTransformer.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/11/3.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import CodableExtensions

struct StringDateTransformer: DecodingContainerTransformer {
    typealias Input = String
    typealias Output = Date

    enum DateType {
        case secondSince1970
    }

    let dateType: DateType

    init(dateType: DateType) {
        self.dateType = dateType
    }

    func transform(_ decoded: String) throws -> Date {

        switch self.dateType {
        case .secondSince1970:
            guard let intValue = Int(decoded) else {
                throw "Failed to transform \(decoded) to Int."
            }

            guard intValue >= 0 else {
                throw "Invalid time interval \(intValue)."
            }

            return Date(timeIntervalSince1970: TimeInterval(intValue))
        }
    }
}
