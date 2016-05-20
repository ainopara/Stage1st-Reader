//
//  TopicListViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//
import UIKit

public enum TopicListPresentationType {
    case History, Favorite
    case Search
    case Forum(key : String)
    case Blank

    init(key: String) {
        switch key {
        case "History":
            self = .History
        case "Favorite":
            self = .Favorite
        case "Search":
            self = .Search
        case "":
            self = .Blank
        default:
            self = .Forum(key: key)
        }
    }
}

extension S1TopicListViewController {

    func isPresentingDatabaseList(key: String) -> Bool {
        switch TopicListPresentationType(key: key) {
        case .Favorite, .History:
            return true
        default:
            return false
        }
    }

    func isPresentingSearchList(key: String) -> Bool {
        switch TopicListPresentationType(key: key) {
        case .Search:
            return true
        default:
            return false
        }
    }

    func isPresentingForumList(key: String) -> Bool {
        switch TopicListPresentationType(key: key) {
        case .Forum:
            return true
        default:
            return false
        }
    }

    func isPresentingBlankList(key: String) -> Bool {
        switch TopicListPresentationType(key: key) {
        case .Blank:
            return true
        default:
            return false
        }
    }
}

// MARK: Style
extension S1TopicListViewController {

    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .LightContent : .Default
    }
}
