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

    func showQuoteFloorViewControllerWithTopic(topic: S1Topic, floors: [S1Floor], htmlString: String, centerFloorID: Int) {
        let viewModel = QuoteFloorViewModel(manager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), topic: topic, floors: floors, htmlString: htmlString, centerFloorID: centerFloorID, baseURL: self.viewModel.dynamicType.pageBaseURL())
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

// MARK: -
extension S1ContentViewController {
    func actionButtonTapped(`for` floorID: NSString) {
        guard let floor = viewModel.searchFloorInCache(floorID.integerValue) else {
            return
        }

        DDLogDebug("[ContentVC] Action for \(floor)")
        let floorActionController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Report", comment: ""), style: .Default, handler: { [weak self] (action) in
            guard let strongSelf = self else { return }
            guard strongSelf.viewModel.topic.formhash != nil && strongSelf.viewModel.topic.fID != nil else {
                strongSelf.alertRefresh()
                return
            }

            guard NSUserDefaults.standardUserDefaults().objectForKey("InLoginStateID") != nil else {
                let loginViewController = S1LoginViewController(nibName: nil, bundle: nil)
                strongSelf.presentViewController(loginViewController, animated: true, completion: nil)
                return
            }

            let reportComposeViewController = ReportComposeViewController(viewModel: strongSelf.viewModel.reportComposeViewModel(floor))
            strongSelf.presentViewController(UINavigationController(rootViewController: reportComposeViewController), animated: true, completion: nil)
        }))

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Reply", comment: ""), style: .Default, handler: { [weak self] (action) in
            guard let strongSelf = self else { return }

            guard strongSelf.viewModel.topic.formhash != nil && strongSelf.viewModel.topic.fID != nil else {
                strongSelf.alertRefresh()
                return
            }

            guard NSUserDefaults.standardUserDefaults().objectForKey("InLoginStateID") != nil else {
                let loginViewController = S1LoginViewController(nibName: nil, bundle: nil)
                strongSelf.presentViewController(loginViewController, animated: true, completion: nil)
                return
            }

            strongSelf.presentReplyViewToFloor(floor)
        }))

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Cancel", comment: ""), style: .Cancel, handler: nil))

        if let popover = floorActionController.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect.zero
        }

        presentViewController(floorActionController, animated: true, completion: nil)
    }

    func alertRefresh() {
        let refreshAlertController = UIAlertController(title: "缺少必要的信息", message: "请长按页码刷新当前页面", preferredStyle: .Alert)
        refreshAlertController.addAction(UIAlertAction(title: "好", style: .Cancel, handler: nil))
        presentViewController(refreshAlertController, animated: true, completion: nil)
    }
}
