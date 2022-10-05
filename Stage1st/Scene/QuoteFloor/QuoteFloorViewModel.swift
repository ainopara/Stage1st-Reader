//
//  FloorViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import WebKit
import CocoaLumberjack

final class QuoteFloorViewModel: NSObject, PageRenderer {
    let initialLink: String
    let topic: S1Topic
    var floors: [Floor] = []

    let centerFloorID: Int
    let baseURL: URL

    init(
        initialLink: String,
        topic: S1Topic,
        centerFloorID: Int,
        baseURL: URL
    ) {
        self.initialLink = initialLink
        self.topic = topic
        self.centerFloorID = centerFloorID
        self.baseURL = baseURL
    }

    func userIsBlocked(with userID: Int) -> Bool {
        return AppEnvironment.current.dataCenter.userIDIsBlocked(ID: userID)
    }

    func loadMoreQuoteFloors() async -> [Floor] {
        var currentFloorLink: String? = initialLink
        var floors = [Floor]()
        do {
            while currentFloorLink != nil {
                var floor = getFloorFromCache(link: currentFloorLink!)
                if floor == nil {
                    floor = try await getFloorFromServer(link: currentFloorLink!)
                }

                let unwrappedFloor = floor!

                S1LogDebug("floor \(unwrappedFloor.id) inserted")
                floors.insert(unwrappedFloor, at: 0)
                currentFloorLink = unwrappedFloor.firstQuoteReplyLink
            }
            return floors
        } catch {
            S1LogWarn("\(error)")
            return floors
        }
    }

    struct FloorInfo {
        let topicID: Int
        let floorID: Int
        let page: Int
    }

    func getFloorFromCache(link: String) -> Floor? {
        guard let floorIDString = Parser.extractQuerys(from: link)["pid"], let floorID = Int(floorIDString) else { return nil }
        return AppEnvironment.current.dataCenter.searchFloorInCache(by: floorID)
    }

    func getFloorFromServer(link: String) async throws -> Floor {
        let topic = try await AppEnvironment.current.apiService.findPost(urlString: link)
        guard topic.topicID == self.topic.topicID else { throw "topicID mismatch \(topic.topicID) != \(self.topic.topicID)" }
        let targetFloorPage = topic.lastViewedPage!.intValue
        guard let targetFloorID = Int(topic.locateFloorIDTag!.replacingOccurrences(of: "pid", with: "")) else { throw "Invalid targetFloorPage: \(targetFloorPage)" }
        S1LogDebug("targetFloorPage: \(targetFloorPage) targetFloorID: \(targetFloorID)")
        let targetPageFloors = try await AppEnvironment.current.dataCenter.floors(topicID: topic.topicID.intValue, page: targetFloorPage)
        guard let floor = targetPageFloors.first(where: { $0.id == targetFloorID }) else { throw "Cound not found \(targetFloorID) in page \(targetFloorPage)" }
        return floor
    }
}

// MARK: - View Model

extension QuoteFloorViewModel: UserViewModelMaker {
    func getUsername(for userID: Int) -> String? {
        floors.first(where: { $0.author.id == userID })?.author.name
    }
}

extension QuoteFloorViewModel: ContentViewModelMaker { }
