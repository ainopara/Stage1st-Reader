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
        let viewModel = S1UserViewModel(user: User(ID: userID.integerValue))
        let userViewController = S1UserViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(userViewController, animated: true)
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
