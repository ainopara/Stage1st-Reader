//
//  S1TopicListViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 3/19/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

enum TopicListPresentationType {
  case History, Favorite
  case Search
  case Forum(key : String)
  case Blank
}

extension S1TopicListViewController {
  func presentationTypeForKey(key: String) -> TopicListPresentationType {
    switch key {
    case "History": return .History
    case "Favorite": return .Favorite
    case "Search": return .Search
    case "": return .Blank
    default: return .Forum(key: key)
    }
  }

  func isPresentingDatabaseList(key: String) -> Bool {
    switch presentationTypeForKey(key) {
    case .Favorite, .History: return true
    default: return false
    }
  }

  func isPresentingSearchList(key: String) -> Bool {
    switch presentationTypeForKey(key) {
    case .Search: return true
    default: return false
    }
  }

  func isPresentingForumList(key: String) -> Bool {
    switch presentationTypeForKey(key) {
    case .Forum: return true
    default: return false
    }
  }

  func isPresentingBlankList(key: String) -> Bool {
    switch presentationTypeForKey(key) {
    case .Blank: return true
    default: return false
    }
  }
}
