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
    case forum(key: String)
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
    override open func viewDidLoad() {
        super.viewDidLoad()

        dataCenter = AppEnvironment.current.dataCenter
        viewModel = S1TopicListViewModel(dataCenter: dataCenter)

        view.addSubview(tableView)
        if #available(iOS 11.0, *) {
            tableView.snp.makeConstraints({ (make) in
                make.leading.trailing.equalTo(view)
            })
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        } else {
            tableView.snp.makeConstraints({ (make) in
                make.leading.trailing.equalTo(view)
                make.top.equalTo(navigationController!.navigationBar.snp.bottom)
            })
        }

        view.addSubview(scrollTabBar)
        scrollTabBar.snp.makeConstraints { (make) in
            make.top.equalTo(tableView.snp.bottom)
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(view.snp.bottom)
        }

        view.addSubview(refreshHUD)
        refreshHUD.snp.makeConstraints { (make) in
            make.center.equalTo(view)
            make.width.lessThanOrEqualTo(view)
            make.height.lessThanOrEqualTo(view)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.updateTabbar), name: Notification.Name.init(rawValue: "S1UserMayReorderedNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.reloadTableData), name: Notification.Name.init(rawValue: "S1TopicUpdateNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(S1TopicListViewController.didReceivePaletteChangeNotification), name: .APPaletteDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.databaseConnectionDidUpdate), name: .UIDatabaseConnectionDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.cloudKitStateChanged), name: .YapDatabaseCloudKitStateChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.cloudKitStateChanged), name: .UIApplicationWillEnterForeground, object: nil)
    }
}

@objc
extension S1TopicListViewController {

    open override func didReceiveMemoryWarning() {
        dataCenter.clearTopicListCache()
        S1Formatter.sharedInstance().clearCache()
    }

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
        return ColorManager.shared.isDarkTheme() ? .lightContent : .default
    }
}
