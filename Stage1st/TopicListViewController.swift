//
//  TopicListViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//
import UIKit

public enum TopicListPresentationType {
    case history, favorite
    case search
    case forum(key : String)
    case blank

    init(key: String) {
        switch key {
        case "History":
            self = .history
        case "Favorite":
            self = .favorite
        case "Search":
            self = .search
        case "":
            self = .blank
        default:
            self = .forum(key: key)
        }
    }
}

extension S1TopicListViewController {

    func isPresentingDatabaseList(_ key: String) -> Bool {
        switch TopicListPresentationType(key: key) {
        case .favorite, .history:
            return true
        default:
            return false
        }
    }

    func isPresentingSearchList(_ key: String) -> Bool {
        switch TopicListPresentationType(key: key) {
        case .search:
            return true
        default:
            return false
        }
    }

    func isPresentingForumList(_ key: String) -> Bool {
        switch TopicListPresentationType(key: key) {
        case .forum:
            return true
        default:
            return false
        }
    }

    func isPresentingBlankList(_ key: String) -> Bool {
        switch TopicListPresentationType(key: key) {
        case .blank:
            return true
        default:
            return false
        }
    }
}

// MARK: Style
extension S1TopicListViewController {

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .lightContent : .default
    }
}
