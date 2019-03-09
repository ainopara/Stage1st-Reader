//
//  Parser.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/3/9.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation

@objc
class Parser: NSObject {

    @objc
    static func extractQuerys(from urlString: String) -> [String: String] {
        var result = [String: String]()

        guard let components = URLComponents(string: urlString) else {
            return result
        }

        for item in components.queryItems ?? [] {
            result[item.name] = item.value
        }

        return result
    }

    static func replyFloorInfo(from responseString: String?) -> [String: String]? {
        guard let responseString = responseString else { return nil }

        let pattern = "<input[^>]*name=\"([^>\"]*)\"[^>]*value=\"([^>\"]*)\""

        let re = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let results = re.matches(in: responseString, options: [], range: NSRange(responseString.startIndex..., in: responseString))

        guard results.count > 0 else {
            return nil
        }

        var info = [String: String]()

        for result in results {
            if
                let keyRange = Range(result.range(at: 1), in: responseString),
                let valueRange = Range(result.range(at: 2), in: responseString)
            {
                let key = responseString[keyRange]
                let value = responseString[valueRange]
                if key == "noticetrimstr" {
                    info[String(key)] = String(value).aibo_stringByUnescapingFromHTML()
                } else {
                    info[String(key)] = String(value)
                }
            } else {
                assertionFailure()
            }
        }

        return info
    }
}
