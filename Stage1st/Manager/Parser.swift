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

    static func extractTopic(from urlString: String) -> S1Topic? {

        // Current Html Scheme
        let result1 = S1Global.regexExtract(from: urlString, withPattern: #"thread-([0-9]+)-([0-9]+)-[0-9]+\.html"#, andColums: [1, 2]) ?? []
        if result1.count == 2 {
            let topicIDString = result1[0]
            let topicPageString = result1[1]

            if let topicID = Int(topicIDString), let topicPage = Int(topicPageString) {
                let topic = S1Topic(topicID: NSNumber(value: topicID))
                topic.lastViewedPage = NSNumber(value: topicPage)
                S1LogDebug("Extract Topic \(topic)")
                return topic
            }
        }

        // Old Html Scheme
        let result2 = S1Global.regexExtract(from: urlString, withPattern: #""read-htm-tid-([0-9]+)\.html""#, andColums: [1]) ?? []
        if result2.count == 1 {
            let topicIDString = result2[0]

            if let topicID = Int(topicIDString) {
                let topic = S1Topic(topicID: NSNumber(value: topicID))
                topic.lastViewedPage = 1
                S1LogDebug("Extract Topic \(topic)")
                return topic
            }
        }

        // PHP Scheme
        let queryDict = self.extractQuerys(from: urlString)
        if
            let topicIDString = queryDict["tid"],
            let topicPageString = queryDict["page"],
            let topicID = Int(topicIDString),
            let topicPage = Int(topicPageString)
        {
            let topic = S1Topic(topicID: NSNumber(value: topicID))
            topic.lastViewedPage = NSNumber(value: topicPage)
            topic.locateFloorIDTag = URLComponents(string: urlString)?.fragment
            S1LogDebug("Extract Topic \(topic)")
            return topic
        }

        S1LogError("Failed to Extract topic from \(urlString)")
        return nil
    }

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
