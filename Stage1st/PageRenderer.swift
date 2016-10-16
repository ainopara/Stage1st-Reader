//
//  PageRenderer.swift
//  Stage1st
//
//  Created by Zheng Li on 10/16/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Mustache
import CocoaLumberjack

protocol PageRenderer {
    var topic: S1Topic { get }
}

extension PageRenderer {
    func templateBundle() -> Bundle {
        let templateBundleURL = Bundle.main.url(forResource: "WebTemplate", withExtension: "bundle")!
        return Bundle.init(url: templateBundleURL)!
    }

    func generatePage(with floors: [Floor]) -> String {
        do {
            let template = try Template(named: "html/thread",
                                        bundle: templateBundle(),
                                        templateExtension: "mustache",
                                        encoding: .utf8)
            let data = Box(_pageData(with: floors, topic: topic))
            let result = try template.render(data)
            return result
        } catch let error {
            DDLogWarn("[PageRenderer] error: \(error)")
            return ""
        }
    }

    func _pageData(with floors: [Floor], topic: S1Topic) -> [String: Any] {
        func fontStyleFile() -> String {
            switch (UIDevice.current.userInterfaceIdiom, UserDefaults.standard.object(forKey: "FontSize") as? String) {
            case (.phone, .some("15px")):
                return "content_15px.css"
            case (.phone, .some("17px")):
                return "content_17px.css"
            case (.phone, .some("19px")):
                return "content_19px.css"
            case (.pad, .some("18px")):
                return "content_ipad_18px.css"
            case (.pad, .some("20px")):
                return "content_ipad_20px.css"
            case (.pad, .some("22px")):
                return "content_ipad_22px.css"
            default:
                return "content_15px.css"
            }
        }

        func colorStyle() -> [String: Any?] {
            return [
                "background": APColorManager.shared.htmlColorStringWithID("5"),
                "text": APColorManager.shared.htmlColorStringWithID("21"),
                "border": APColorManager.shared.htmlColorStringWithID("14"),
                "borderText": APColorManager.shared.htmlColorStringWithID("17")
            ]
        }

        func floorsData() -> [[String: Any?]] {
            var isFirstInPage = true
            var data = [[String: Any?]]()
            for floor in floors {
                data.append(_floorData(with: floor, topicAuthorID: topic.authorUserID as? Int, isFirstInPage: isFirstInPage))
                isFirstInPage = false
            }
            return data
        }

        return [
            "font-style-file": fontStyleFile(),
            "color": colorStyle(),
            "floors": floorsData()
        ]
    }

    func _floorData(with floor: Floor, topicAuthorID: Int?, isFirstInPage: Bool) -> [String: Any?] {
        func processContent(content: String?) -> String {
            guard let content = content else {
                DDLogWarn("[PageRenderer] nil content in floor \(floor.ID)")
                return ""
            }
            let firstProcessedContent = S1ContentViewModel.processHTMLString(content, withFloorID: floor.ID)
            let secondProcessedContent = UserDefaults.standard.bool(forKey: "RemoveTails") ? S1ContentViewModel.stripTails(firstProcessedContent) : firstProcessedContent
            return secondProcessedContent
        }

        func processAuthor(floor: Floor) -> String {
            if let topicAuthorID = topicAuthorID, topicAuthorID == floor.author.ID, let floorIndexMark = floor.indexMark, floorIndexMark != "楼主" {
                return "\(floor.author.name) (楼主)"
            }

            return floor.author.name
        }

        func processIndexMark(indexMark: String?) -> String {
            switch indexMark {
            case .none:
                return "N"
            case .some(let mark) where mark != "楼主":
                return "#\(mark)"
            default:
                return "楼主"
            }
        }

        return [
            "index-mark": processIndexMark(indexMark: floor.indexMark),
            "author-ID": floor.author.ID,
            "author-name": processAuthor(floor: floor),
            "post-time": floor.creationDate?.s1_gracefulDateTimeString() ?? "无日期",
            "ID": "\(floor.ID)",
            "poll": nil,
            "content": processContent(content: floor.content),
            "attachments": floor.imageAttachmentURLStringList,
            "is-first": isFirstInPage
        ]
    }
}
