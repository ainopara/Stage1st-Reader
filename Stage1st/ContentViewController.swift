//
//  ContentViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/10/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import WebKit
import CocoaLumberjack
import Crashlytics

private let topOffset: CGFloat = -80.0
private let bottomOffset: CGFloat = 60.0

class S1ContentViewController: UIViewController {
    let viewModel: S1ContentViewModel
    let dataCenter: S1DataCenter

    var toolBar = UIToolbar(frame: .zero)
    var webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    lazy var pullToActionController: PullToActionController = {
        return PullToActionController(scrollView: self.webView.scrollView)
    }()

    var refreshHUD = S1HUD(frame: .zero)
    var hintHUD = S1HUD(frame: .zero)

    var backButton = UIButton(frame: .zero)
    var forwardButton = UIButton(frame: .zero)
    var pageButton = UIButton(frame: .zero)
    var favoriteButton = UIButton(frame: .zero)
    lazy var actionBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(actionButtonTapped(for:)))
    }()

    var titleLabel = UILabel(frame: .zero)
    var topDecorateLine = UIView(frame: .zero)
    var bottomDecorateLine = UIView(frame: .zero)

    var attributedReplyDraft: NSMutableAttributedString? = nil

    weak var replyTopicFloor: Floor?
    var scrollType: S1ContentScrollType = .restorePosition
    var webPageAutomaticScrollingEnabled: Bool = true
    var webPageDocumentReadyForAutomaticScrolling: Bool = false
    var webPageContentSizeChangedForAutomaticScrolling: Bool = false
    var finishFirstLoading: Bool = false
    var presentingImageViewer: Bool = false
    var presentingWebViewer: Bool = false
    var presentingContentViewController: Bool = false

    convenience init(topic: S1Topic, dataCenter: S1DataCenter) {
        self.init(viewModel: S1ContentViewModel(topic: topic, dataCenter: dataCenter))
    }

    init(viewModel: S1ContentViewModel) {
        self.viewModel = viewModel
        self.dataCenter = viewModel.dataCenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.presentingImageViewer = false
        self.presentingWebViewer = false
        self.presentingContentViewController = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Crashlytics.sharedInstance().setObjectValue("ContentViewController", forKey: "lastViewController")
        DDLogDebug("[ContentVC] View did appear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        guard
            !self.presentingImageViewer,
            !self.presentingWebViewer,
            !self.presentingContentViewController else {
            return
        }

        DDLogDebug("[ContentVC] View did disappear begin")
//        [self cancelRequest];
//        [self saveTopicViewedState:nil];
        DDLogDebug("[ContentVC] View did disappear end")
    }

    deinit {
        DDLogInfo("[ContentVC] Dealloc Begin")
        NotificationCenter.default.removeObserver(self)
        self.pullToActionController.delegate = nil
        self.webView.navigationDelegate = nil
        self.webView.scrollView.delegate = nil
        self.webView.stopLoading()
        DDLogInfo("[ContentVC] Dealloced")
    }
}

// MARK: - Style
extension S1ContentViewController {
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .lightContent : .default
    }
}

// MARK: Navigation
extension S1ContentViewController {
    func showUserViewController(_ userID: NSNumber) {
        let viewModel = UserViewModel(manager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), user: User(ID: userID.intValue, name: ""))
        let userViewController = UserViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(userViewController, animated: true)
    }

    func showQuoteFloorViewControllerWithTopic(_ topic: S1Topic, floors: [Floor], htmlString: String, centerFloorID: Int) {
        let viewModel = QuoteFloorViewModel(manager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), topic: topic, floors: floors, htmlString: htmlString, centerFloorID: centerFloorID, baseURL: type(of: self.viewModel).pageBaseURL())
        let quoteFloorViewController = S1QuoteFloorViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(quoteFloorViewController, animated: true)
    }
}

// MARK: NSUserActivity
extension S1ContentViewController {
    func _setupActivity() {
        DispatchQueue.global().async { [weak self] in
            guard let strongSelf = self else { return }
            let activity = NSUserActivity(activityType: "Stage1st.view-topic")
            activity.title = strongSelf.viewModel.activityTitle()
            activity.userInfo = strongSelf.viewModel.activityUserInfo()
            activity.webpageURL = strongSelf.viewModel.correspondingWebPageURL() as URL?

            if #available(iOS 9.0, *) {
                activity.isEligibleForSearch = true
                activity.requiredUserInfoKeys = Set(arrayLiteral: "topicID")
            }

            DispatchQueue.main.async(execute: {
                guard let strongSelf = self else { return }
                strongSelf.userActivity = activity
            })
        }
    }

    open override func updateUserActivityState(_ activity: NSUserActivity) {
        DDLogDebug("[ContentVC] Hand Off Activity Updated")
        activity.userInfo = self.viewModel.activityUserInfo()
        activity.webpageURL = self.viewModel.correspondingWebPageURL() as URL?
    }
}

// MARK: - Actions
extension S1ContentViewController {
    func actionButtonTapped(for floorID: NSString) {
        guard let floor = viewModel.searchFloorInCache(floorID.integerValue) else {
            return
        }

        DDLogDebug("[ContentVC] Action for \(floor)")
        let floorActionController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Report", comment: ""), style: .default, handler: { [weak self] (action) in
            guard let strongSelf = self else { return }
            guard strongSelf.viewModel.topic.formhash != nil && strongSelf.viewModel.topic.fID != nil else {
                strongSelf.alertRefresh()
                return
            }

            guard UserDefaults.standard.object(forKey: "InLoginStateID") != nil else {
                let loginViewController = S1LoginViewController(nibName: nil, bundle: nil)
                strongSelf.present(loginViewController, animated: true, completion: nil)
                return
            }

            let reportComposeViewController = ReportComposeViewController(viewModel: strongSelf.viewModel.reportComposeViewModel(floor))
            strongSelf.present(UINavigationController(rootViewController: reportComposeViewController), animated: true, completion: nil)
        }))

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Reply", comment: ""), style: .default, handler: { [weak self] (action) in
            guard let strongSelf = self else { return }

            guard strongSelf.viewModel.topic.formhash != nil && strongSelf.viewModel.topic.fID != nil else {
                strongSelf.alertRefresh()
                return
            }

            guard UserDefaults.standard.object(forKey: "InLoginStateID") != nil else {
                let loginViewController = S1LoginViewController(nibName: nil, bundle: nil)
                strongSelf.present(loginViewController, animated: true, completion: nil)
                return
            }

//            strongSelf.presentReplyView(to: floor)
        }))

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Cancel", comment: ""), style: .cancel, handler: nil))

        if let popover = floorActionController.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect.zero
        }

        present(floorActionController, animated: true, completion: nil)
    }

    func alertRefresh() {
        let refreshAlertController = UIAlertController(title: "缺少必要的信息", message: "请长按页码刷新当前页面", preferredStyle: .alert)
        refreshAlertController.addAction(UIAlertAction(title: "好", style: .cancel, handler: nil))
        present(refreshAlertController, animated: true, completion: nil)
    }
}

// MARK: - PullToActionDelagete
extension S1ContentViewController: PullToActionDelagete {
    public func scrollViewDidEndDraggingOutsideTopBoundWithOffset(_ offset: CGFloat) {
        guard
            offset < topOffset,
            self.finishFirstLoading,
            !self._isInFirstPage() else {
            return
        }

        var currentContentOffset = self.webView.scrollView.contentOffset
        currentContentOffset.y = -self.webView.bounds.height

        // DIRTYHACK: delay 0.01 second to avoid animation to overrided by other animation setted by iOS
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.webView.scrollView.setContentOffset(currentContentOffset, animated: false)
                strongSelf.webView.scrollView.alpha = 0.0
            }, completion: { [weak self] (finished) in
                guard let strongSelf = self else { return }
                strongSelf.scrollType = .pullDownForPrevious
//                strongSelf.back(nil)
            })
        }
    }

    public func scrollViewDidEndDraggingOutsideBottomBoundWithOffset(_ offset: CGFloat) {
        guard
            offset > bottomOffset,
            self.finishFirstLoading else {
            return
        }

        guard !self._isInLastPage() else {
            // Only refresh triggered in last page
//            self.forward(nil)
            return
        }

        var currentContentOffset = self.webView.scrollView.contentOffset
        currentContentOffset.y = -self.webView.scrollView.contentSize.height

        // DIRTYHACK: delay 0.01 second to avoid animation to overrided by other animation setted by iOS
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.webView.scrollView.setContentOffset(currentContentOffset, animated: false)
                strongSelf.webView.scrollView.alpha = 0.0
            }, completion: { [weak self] (finished) in
                guard let strongSelf = self else { return }
                strongSelf.scrollType = .pullUpForNext
//                strongSelf.forward(nil)
            })
        }
    }

    public func scrollViewContentSizeDidChange(_ contentSize: CGSize) {
//        self.updateDecorationLines(contentSize)
        self.webPageContentSizeChangedForAutomaticScrolling = true
    }

    public func scrollViewContentOffsetProgress(_ progress: [String : Double]) {
        guard self.finishFirstLoading else {
            if self._isInLastPage() {
                self.forwardButton.setImage(#imageLiteral(resourceName: "Refresh_black"), for: .normal)
            }
            self.forwardButton.imageView?.layer.transform = CATransform3DIdentity
            self.backButton.imageView?.layer.transform = CATransform3DIdentity
            return
        }

        // Process for bottom offset
        if let bottomProgress = progress["bottom"] {
            if self._isInLastPage() {
                let image = bottomProgress >= 0.0 ? #imageLiteral(resourceName: "Refresh_black") : #imageLiteral(resourceName: "Forward")
                let rotateAngle: CGFloat = CGFloat(bottomProgress >= 0.0 ? M_PI_2 * bottomProgress : M_PI_2)

                self.forwardButton.setImage(image, for: .normal)
                self.forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, rotateAngle, 0.0, 0.0, 1.0)
            } else {
                let limitedBottomProgress = max(min(bottomProgress, 1.0), 0.0)
                self.forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * limitedBottomProgress), 0.0, 0.0, 1.0)
            }
        }

        // Process for top offset
        if self._isInFirstPage() {
            self.backButton.imageView?.layer.transform = CATransform3DIdentity
        } else {
            if let topProgress = progress["top"] {
                let limitedTopProgress = max(min(topProgress, 1.0), 0.0)
                self.backButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * limitedTopProgress), 0.0, 0.0, 1.0)
            }
        }
    }
}

// MARK: - Helper
extension S1ContentViewController {
    func _isInFirstPage() -> Bool {
        return self.viewModel.currentPage == 1
    }
    func _isInLastPage() -> Bool {
        return self.viewModel.currentPage >= self.viewModel.totalPages
    }
}
