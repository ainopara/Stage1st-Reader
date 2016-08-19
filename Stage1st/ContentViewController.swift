//
//  ContentViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/10/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//
import CocoaLumberjack

// MARK: Style
extension S1ContentViewController {
    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .LightContent : .Default
    }
}

// MARK: Navigation
extension S1ContentViewController {
    func showUserViewController(userID: NSNumber) {
        let viewModel = UserViewModel(manager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), user: User(ID: userID.integerValue, name: ""))
        let userViewController = UserViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(userViewController, animated: true)
    }

    func showQuoteFloorViewControllerWithTopic(topic: S1Topic, floors: [S1Floor]) {
        let viewModel = QuoteFloorViewModel(manager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), topic: topic, floors: floors, baseURL: self.viewModel.dynamicType.pageBaseURL())
        let quoteFloorViewController = S1QuoteFloorViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(quoteFloorViewController, animated: true)
    }
}

// MARK: NSUserActivity
extension S1ContentViewController {
    func setupActivity() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { [weak self] in
            guard let strongSelf = self else { return }
            let activity = NSUserActivity(activityType: "Stage1st.view-topic")
            activity.title = strongSelf.viewModel.activityTitle()
            activity.userInfo = strongSelf.viewModel.activityUserInfo()
            activity.webpageURL = strongSelf.viewModel.correspondingWebPageURL()

            if #available(iOS 9.0, *) {
                activity.eligibleForSearch = true
                activity.requiredUserInfoKeys = Set(arrayLiteral: "topicID")
            }

            dispatch_async(dispatch_get_main_queue(), {
                guard let strongSelf = self else { return }
                strongSelf.userActivity = activity
            })
        }
    }

    public override func updateUserActivityState(activity: NSUserActivity) {
        DDLogDebug("[ContentVC] Hand Off Activity Updated")
        activity.userInfo = self.viewModel.activityUserInfo()
        activity.webpageURL = self.viewModel.correspondingWebPageURL()
    }
}

extension S1ContentViewController {
    func reportViewController() -> UIViewController {
        return ReportComposeViewController(viewModel: ReportComposeViewModel(apiManager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), topic: S1Topic(), floor: S1Floor()))
    }
}
