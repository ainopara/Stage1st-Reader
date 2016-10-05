//
//  ContentViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/10/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import WebKit
import SnapKit
import CocoaLumberjack
import ActionSheetPicker_3_0
import Crashlytics

fileprivate let topOffset: CGFloat = -80.0
fileprivate let bottomOffset: CGFloat = 60.0

class S1ContentViewController: UIViewController {
    let viewModel: S1ContentViewModel

    var toolBar = UIToolbar(frame: .zero)
    var webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    lazy var pullToActionController: PullToActionController = {
        return PullToActionController(scrollView: self.webView.scrollView)
    }()

    var refreshHUD = S1HUD(frame: .zero)
    var hintHUD = S1HUD(frame: .zero)

    var backButton = UIButton(type: .system)
    var forwardButton = UIButton(type: .system)
    var pageButton = UIButton(frame: .zero)
    var favoriteButton = UIButton(frame: .zero)
    lazy var actionBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(action(sender:)))
    }()

    var titleLabel = UILabel(frame: .zero)
    var topDecorateLine = UIView(frame: .zero)
    var bottomDecorateLine = UIView(frame: .zero)

    var attributedReplyDraft: NSMutableAttributedString? = nil
    weak var replyTopicFloor: Floor?

    var scrollType: ScrollType = .restorePosition

    var backButtonState: BackButtonState = .back(rotateAngle: 0.0) {
        didSet {
            switch backButtonState {
            case .back(let rotateAngle):
                if case .back(let oldRotateAngle) = oldValue {
                    if rotateAngle != oldRotateAngle {
                        backButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                    }
                } else {
                    backButton.setImage(#imageLiteral(resourceName: "Back"), for: .normal)
                    backButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                }
            case .cachedBack(let rotateAngle):
                if case .cachedBack(let oldRotateAngle) = oldValue {
                    if rotateAngle != oldRotateAngle {
                        backButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                    }
                } else {
                    backButton.setImage(#imageLiteral(resourceName: "Back-Cached"), for: .normal)
                    backButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                }
            }
        }
    }

    var forwardButtonState: ForwardButtonState = .forward(rotateAngle: 0.0) {
        didSet {
            switch forwardButtonState {
            case .forward(let rotateAngle):
                if case .forward(let oldRotateAngle) = oldValue {
                    if rotateAngle != oldRotateAngle {
                        forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                    }
                } else {
                    forwardButton.setImage(#imageLiteral(resourceName: "Forward"), for: .normal)
                    forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                }
            case .cachedForward(let rotateAngle):
                if case .cachedForward(let oldRotateAngle) = oldValue {
                    if rotateAngle != oldRotateAngle {
                        forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                    }
                } else {
                    forwardButton.setImage(#imageLiteral(resourceName: "Forward-Cached"), for: .normal)
                    forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                }
            case .refresh(let rotateAngle):
                if case .refresh(let oldRotateAngle) = oldValue {
                    if rotateAngle != oldRotateAngle {
                        forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                    }
                } else {
                    forwardButton.setImage(#imageLiteral(resourceName: "Refresh_black"), for: .normal)
                    forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                }
            }
        }
    }

    var webPageAutomaticScrollingEnabled = true
    var webPageReadyForAutomaticScrolling = false
    var webPageSizeChangedForAutomaticScrolling = false
    var finishFirstLoading = false
    var presentingImageViewer = false
    var presentingWebViewer = false
    var presentingContentViewController = false

    // MARK: -
    convenience init(topic: S1Topic, dataCenter: S1DataCenter) {
        self.init(viewModel: S1ContentViewModel(topic: topic, dataCenter: dataCenter))
    }

    init(viewModel: S1ContentViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        // Toolbar
        toolBar.isTranslucent = false

        // Back button
        backButton.setImage(#imageLiteral(resourceName: "Back"), for: .normal)
        backButton.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 30.0)
        backButton.imageView?.contentMode = .center
        backButton.addTarget(self, action: #selector(back(sender:)), for: .touchUpInside)
        let backLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(backLongPressed(gestureRecognizer:)))
        backLongPressGestureRecognizer.minimumPressDuration = 0.5
        backButton.addGestureRecognizer(backLongPressGestureRecognizer)

        // Forward button
        let image = _isInLastPage() ? #imageLiteral(resourceName: "Refresh_black") : #imageLiteral(resourceName: "Forward")
        forwardButton.setImage(image, for: .normal)
        forwardButton.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 30.0)
        forwardButton.imageView?.contentMode = .center
        forwardButton.addTarget(self, action: #selector(forward(sender:)), for: .touchUpInside)
        let forwardLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(forwardLongPressed(gestureRecognizer:)))
        forwardLongPressGestureRecognizer.minimumPressDuration = 0.5
        forwardButton.addGestureRecognizer(forwardLongPressGestureRecognizer)

        // Page button
        pageButton.frame = CGRect(x: 0.0, y: 0.0, width: 80.0, height: 30.0)
        pageButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
        pageButton.backgroundColor = .clear
        pageButton.titleLabel?.textAlignment = .center
        pageButton.addTarget(self, action: #selector(pickPage(sender:)), for: .touchUpInside)
        let forceRefreshGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(forceRefreshPressed(gestureRecognizer:)))
        forceRefreshGestureRecognizer.minimumPressDuration = 0.5
        pageButton.addGestureRecognizer(forceRefreshGestureRecognizer)

        // WebView
        webView.navigationDelegate = self
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        webView.isOpaque = false

        // Pull to action
        pullToActionController.addConfiguration(withName: "top", baseLine: .top, beginPosition: 0.0, endPosition: Double(topOffset))
        pullToActionController.addConfiguration(withName: "bottom", baseLine: .bottom, beginPosition: 0.0, endPosition: Double(bottomOffset))
        pullToActionController.delegate = self

        // Title label
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .center

        if let title = self.viewModel.topic.title, title != "" {
            titleLabel.text = title
        } else {
            titleLabel.text = "\(self.viewModel.topic.topicID) 载入中..."
        }

        // Toolbar items
        let forwardItem = UIBarButtonItem(customView: forwardButton)
        let backwardItem = UIBarButtonItem(customView: backButton)
        favoriteButton.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 30.0)
        favoriteButton.imageView?.clipsToBounds = false
        favoriteButton.imageView?.contentMode = .center
        let favoriteItem = UIBarButtonItem(customView: favoriteButton)

        updateToolBar()

        let labelItem = UIBarButtonItem(customView: pageButton)
        labelItem.width = 80.0

        let fixItem = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixItem.width = 26.0

        let fixItem2 = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixItem2.width = 48.0

        let flexItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        if !shouldPresentingFavoriteButtonOnToolBar() {
            favoriteItem.customView?.bounds = .zero
            favoriteItem.customView?.isHidden = true
            fixItem2.width = 0.0
        }

        toolBar.setItems([backwardItem, fixItem, forwardItem, flexItem, labelItem, flexItem, favoriteItem, fixItem2, actionBarButtonItem], animated: false)

        perform(Selector(("viewDidLoadObjC")))

        // Activity
        _setupActivity()

        // Notification
        NotificationCenter.default.addObserver(self, selector: #selector(saveTopicViewedState(sender:)), name: .UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didReceivePaletteChangeNotification(_:)), name: .APPaletteDidChangeNotification, object: nil)

        // Fetch
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.fetchContentForCurrentPage(forceUpdate: strongSelf._isInLastPage())
        }

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

// MARK: - Life Cycle
extension S1ContentViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(toolBar)
        toolBar.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(self.view)
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
        }

        view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(self.view)
            make.top.equalTo(self.topLayoutGuide.snp.bottom)
            make.bottom.equalTo(self.toolBar.snp.top)
        }

        view.layoutIfNeeded()

        webView.scrollView.addSubview(topDecorateLine)
        topDecorateLine.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(self.webView)
            make.height.equalTo(1.0)
            make.bottom.equalTo(self.webView.scrollView.subviews[0].snp.top).offset(topOffset)
        }

        webView.scrollView.addSubview(bottomDecorateLine)
        bottomDecorateLine.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(self.webView)
            make.height.equalTo(1.0)
            make.top.equalTo(self.webView.scrollView.subviews[0].snp.bottom).offset(bottomOffset)
        }

        webView.scrollView.insertSubview(titleLabel, at: 0)
        titleLabel.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.webView.scrollView.subviews[1].snp.top)
            make.centerX.equalTo(self.webView.scrollView.snp.centerX)
            make.width.equalTo(self.webView.scrollView.snp.width).offset(-24.0)
        }

        view.addSubview(refreshHUD)
        refreshHUD.snp.makeConstraints { (make) in
            make.center.equalTo(self.view)
            make.width.lessThanOrEqualTo(self.view).priority(250.0)
        }

        view.addSubview(hintHUD)
        hintHUD.snp.makeConstraints { (make) in
            make.centerX.equalTo(self.view.snp.centerX)
            make.bottom.equalTo(self.toolBar.snp.top).offset(-10.0)
            make.width.lessThanOrEqualTo(self.view.snp.width)
        }

        view.layoutIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.presentingImageViewer = false
        self.presentingWebViewer = false
        self.presentingContentViewController = false

        self.didReceivePaletteChangeNotification(nil)

        // defer from initializer to here to make sure navigationController exist (i.e. self be added to navigation stack)
        // FIXME: find a way to make sure this only called once.
        if let colorPanRecognizer = (self.navigationController?.delegate as? NavigationControllerDelegate)?.colorPanRecognizer {
            webView.scrollView.panGestureRecognizer.require(toFail: colorPanRecognizer)
        }
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
        cancelRequest()
        saveTopicViewedState(sender: nil)
        DDLogDebug("[ContentVC] View did disappear end")
    }
}

// MARK: - Actions
extension S1ContentViewController {
    open func back(sender: Any?) {
        if _isInFirstPage() {
            _ = self.navigationController?.popViewController(animated: true)
        } else {
            _hook_preChangeCurrentPage()
            self.viewModel.currentPage -= 1
            self.fetchContentForCurrentPage(forceUpdate: false)
        }
    }

    open func forward(sender: Any?) {

        func scrollToBottom(animated: Bool) {
            let offset = CGPoint(x: 0.0, y: webView.scrollView.contentSize.height - webView.scrollView.bounds.height)
            webView.scrollView.setContentOffset(offset, animated: animated)
        }

        switch (_isInLastPage(), self.webView.s1_atBottom()) {
        case (true, false):
            scrollToBottom(animated: true)
            break
        case (true, true):
            forceRefreshCurrentPage()
            break
        case (false, _):
            _hook_preChangeCurrentPage()
            self.viewModel.currentPage += 1
            self.fetchContentForCurrentPage(forceUpdate: false)
            break
        default:
            DDLogError("This should never happen, just make swift compiler happy.")
        }
    }

    open func backLongPressed(gestureRecognizer: UIGestureRecognizer) {
        guard
            gestureRecognizer.state == UIGestureRecognizerState.began,
            !_isInFirstPage() else {
            return
        }

        _hook_preChangeCurrentPage()
        viewModel.currentPage = 1
        self.fetchContentForCurrentPage(forceUpdate: false)
    }

    open func forwardLongPressed(gestureRecognizer: UIGestureRecognizer) {
        guard
            gestureRecognizer.state == UIGestureRecognizerState.began,
            !_isInLastPage() else {
            return
        }

        _hook_preChangeCurrentPage()
        self.viewModel.currentPage = self.viewModel.totalPages
        self.fetchContentForCurrentPage(forceUpdate: false)
    }

    open func pickPage(sender: Any?) {
        func generatePageList() -> [String] {
            var pageList = [String]()

            for page in 1...max(viewModel.currentPage, viewModel.totalPages) {
                if viewModel.dataCenter.hasPrecacheFloors(for: viewModel.topic, withPage: NSNumber(value: page)) {
                    pageList.append("✓第 \(page) 页✓")
                } else {
                    pageList.append("第 \(page) 页")
                }
            }

            return pageList
        }

        let pageList = generatePageList()

        let picker = ActionSheetStringPicker(title: "", rows: pageList, initialSelection: Int(viewModel.currentPage - 1), doneBlock: { [weak self] (picker, selectedIndex, selectedValue) in
            guard let strongSelf = self else { return }

            if strongSelf.viewModel.currentPage == UInt(selectedIndex + 1) {
                strongSelf.forceRefreshCurrentPage()
            } else {
                strongSelf._hook_preChangeCurrentPage()
                strongSelf.viewModel.currentPage = UInt(selectedIndex + 1)
                strongSelf.fetchContentForCurrentPage(forceUpdate: false)
            }
        }, cancel: nil, origin: pageButton)

        picker?.pickerBackgroundColor = APColorManager.shared.colorForKey("content.picker.background")
        picker?.toolbarBackgroundColor = APColorManager.shared.colorForKey("appearance.toolbar.bartint")
        picker?.toolbarButtonsColor = APColorManager.shared.colorForKey("appearance.toolbar.tint")

        let labelParagraphStyle = NSMutableParagraphStyle()
        labelParagraphStyle.alignment = .center
        picker?.pickerTextAttributes = [
            NSParagraphStyleAttributeName: labelParagraphStyle,
            NSFontAttributeName: UIFont.systemFont(ofSize: 19.0),
            NSForegroundColorAttributeName: APColorManager.shared.colorForKey("content.picker.text")
        ]
        picker?.show()
    }

    open func forceRefreshPressed(gestureRecognizer: UIGestureRecognizer) {
        guard gestureRecognizer.state == .began else {
            return
        }

        DDLogDebug("[ContentVC] Force refresh pressed")
        forceRefreshCurrentPage()
    }

    open func action(sender: Any?) {

    }

    open func saveTopicViewedState(sender: Any?) {
        if finishFirstLoading {
            viewModel.saveTopicViewedState(lastViewedPosition: Double(webView.scrollView.contentOffset.y))
        } else {
            viewModel.saveTopicViewedState(lastViewedPosition: nil)
        }
    }

    open override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        // Color
        view.backgroundColor = APColorManager.shared.colorForKey("content.background")
        webView.backgroundColor = APColorManager.shared.colorForKey("content.webview.background")
        topDecorateLine.backgroundColor = APColorManager.shared.colorForKey("content.decoration.line")
        bottomDecorateLine.backgroundColor = APColorManager.shared.colorForKey("content.decoration.line")
        if let title = self.viewModel.topic.title, title != "" {
            titleLabel.textColor = APColorManager.shared.colorForKey("content.titlelabel.text.normal")
        } else {
            titleLabel.textColor = APColorManager.shared.colorForKey("content.titlelabel.text.disable")
        }
        pageButton.setTitleColor(APColorManager.shared.colorForKey("content.pagebutton.text"), for: .normal)
        toolBar.barTintColor = APColorManager.shared.colorForKey("appearance.toolbar.bartint")
        toolBar.tintColor = APColorManager.shared.colorForKey("appearance.toolbar.tint")

        setNeedsStatusBarAppearanceUpdate()

        if notification != nil {
            saveViewPositionForCurrentPage()
            fetchContentForCurrentPage(forceUpdate: false)
        }
    }

    open func actionButtonTapped(for floorID: NSString) {
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

            strongSelf.presentReplyView(toFloor: floor)
        }))

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Cancel", comment: ""), style: .cancel, handler: nil))

        if let popover = floorActionController.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect.zero
        }

        present(floorActionController, animated: true, completion: nil)
    }

    open func alertRefresh() {
        let refreshAlertController = UIAlertController(title: "缺少必要的信息", message: "请长按页码刷新当前页面", preferredStyle: .alert)
        refreshAlertController.addAction(UIAlertAction(title: "好", style: .cancel, handler: nil))
        present(refreshAlertController, animated: true, completion: nil)
    }
}

// MARK: -
// MARK: WKNavigationDelegate
extension S1ContentViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        DDLogInfo("[ContentVC] did commit navigation: \(navigation)")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DDLogInfo("[ContentVC] webViewDidFinishLoad")
        _hook_didFinishFullPageLoad(for: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DDLogWarn("[ContentVC] webview failed to load with error: \(error)")
        _hook_didFinishFullPageLoad(for: webView)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if url.absoluteString == "about:blank" {
            decisionHandler(.allow)
            return
        }

        if url.absoluteString.hasPrefix("file://") {
            if url.absoluteString.hasSuffix("html") {
                decisionHandler(.allow)
                return
            }
        }

        DDLogWarn("no case match for url: \(url), fallback cancel")
        decisionHandler(.cancel)
        return
    }
}

// MARK: PullToActionDelagete
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
                strongSelf.back(sender: nil)
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
            self.forward(sender: nil)
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
                strongSelf.forward(sender: nil)
            })
        }
    }

    public func scrollViewContentSizeDidChange(_ contentSize: CGSize) {
        _updateDecorationLines(contentSize: contentSize)
        webPageSizeChangedForAutomaticScrolling = true
    }

    public func scrollViewContentOffsetProgress(_ progress: [String : Double]) {
        guard finishFirstLoading else {
            if _isInLastPage() {
                forwardButtonState = .refresh(rotateAngle: 0.0)
            }
            // back state set depend on cache info
            return
        }

        // Process for bottom offset
        if let bottomProgress = progress["bottom"] {
            if _isInLastPage() {
                if bottomProgress >= 0 {
                    forwardButtonState = .refresh(rotateAngle: bottomProgress)
                } else {
                    forwardButtonState = .forward(rotateAngle: 1.0)
                }
            } else {
                let limitedBottomProgress = max(min(bottomProgress, 1.0), 0.0)
                forwardButtonState = .forward(rotateAngle: limitedBottomProgress) // FIXME: or .cachedForward judge depending on cache state
            }
        }

        // Process for top offset
        if let topProgress = progress["top"] {
            if _isInFirstPage() {
                backButtonState = .back(rotateAngle: 0.0)
            } else {
                let limitedTopProgress = max(min(topProgress, 1.0), 0.0)
                backButtonState = .back(rotateAngle: limitedTopProgress)
            }
        }
    }
}

// MARK: REComposeViewControllerDelegate
extension S1ContentViewController: REComposeViewControllerDelegate {
    func composeViewController(_ composeViewController: REComposeViewController!, didFinishWith result: REComposeResult) {
        attributedReplyDraft = composeViewController.textView.attributedText.mutableCopy() as? NSMutableAttributedString
        switch result {
        case .cancelled:
            composeViewController.dismiss(animated: true, completion: nil)
        case .posted:
            guard composeViewController.plainText.characters.count > 0 else {
                return
            }

            let successBlock = { [weak self] in
//                [[MTStatusBarOverlay sharedInstance] postFinishMessage:@"回复成功" duration:2.5 animated:YES];
                guard let strongSelf = self else { return }
                strongSelf.attributedReplyDraft = nil
                if strongSelf._isInLastPage() {
                    strongSelf.scrollType = .toBottom
                    strongSelf.fetchContentForCurrentPage(forceUpdate: true)
                }
            }

            let failureBlock = { (error: Error) in
                let nserror = error as NSError

                if nserror.domain == NSURLErrorDomain && nserror.code == NSURLErrorCancelled {
                    DDLogDebug("[Network] NSURLErrorCancelled")
//                    [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复请求取消" duration:1.0 animated:YES];
                } else {
                    DDLogDebug("[Network] reply error: \(nserror)")
//                    [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复失败" duration:2.5 animated:YES];
                }
            }

            // [[MTStatusBarOverlay sharedInstance] postMessage:@"回复发送中" animated:YES];

            if let replyTopicFloor = replyTopicFloor {
                viewModel.dataCenter.replySpecificFloor(replyTopicFloor, in: viewModel.topic, atPage: NSNumber(value: viewModel.currentPage), withText: composeViewController.plainText, success: successBlock, failure: failureBlock)
            } else {
                viewModel.dataCenter.reply(viewModel.topic, withText: composeViewController.plainText, success: successBlock, failure: failureBlock)
            }

            composeViewController.dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: - Style
extension S1ContentViewController {
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return APColorManager.shared.isDarkTheme() ? .lightContent : .default
    }
}

// MARK: Navigation
extension S1ContentViewController {
    func showUserViewController(_ userID: NSNumber) {
        let viewModel = UserViewModel(manager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), user: User(ID: userID.intValue, name: ""))
        let userViewController = UserViewController(viewModel: viewModel)
        navigationController?.pushViewController(userViewController, animated: true)
    }

    func showQuoteFloorViewControllerWithTopic(_ topic: S1Topic, floors: [Floor], htmlString: String, centerFloorID: Int) {
        let viewModel = QuoteFloorViewModel(manager: DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b"), topic: topic, floors: floors, htmlString: htmlString, centerFloorID: centerFloorID, baseURL: type(of: self.viewModel).pageBaseURL())
        let quoteFloorViewController = S1QuoteFloorViewController(viewModel: viewModel)
        navigationController?.pushViewController(quoteFloorViewController, animated: true)
    }
}

// MARK: NSUserActivity (aspect)
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
        activity.userInfo = viewModel.activityUserInfo()
        activity.webpageURL = viewModel.correspondingWebPageURL() as URL?
    }
}

// MARK: - Reply (aspect)
extension S1ContentViewController {
    func presentReplyView(toFloor floor: Floor?) {
        // Check in login state.
        guard viewModel.topic.fID != nil, viewModel.topic.formhash != nil else {
            alertRefresh()
            return
        }

        guard let _ = UserDefaults.standard.value(forKey: "InLoginStateID") else {
            let loginViewController = S1LoginViewController(nibName: nil, bundle: nil)
            present(loginViewController, animated: true, completion: nil)
            return
        }

        let replyViewController = REComposeViewController(nibName: nil, bundle: nil)

        // configure
        replyViewController.textView.keyboardAppearance = APColorManager.shared.isDarkTheme() ? .dark : .default
        replyViewController.textView.tintColor = APColorManager.shared.colorForKey("reply.tint")
        replyViewController.textView.textColor = APColorManager.shared.colorForKey("reply.text")
        replyViewController.sheetBackgroundColor = APColorManager.shared.colorForKey("reply.background")

        replyTopicFloor = floor
        if let floor = floor {
            replyViewController.title = "@\(floor.author.name)"
        } else {
            replyViewController.title = NSLocalizedString("ContentView_Reply_Title", comment: "Reply")
        }

        if let replyDraft = attributedReplyDraft {
            replyViewController.textView.attributedText = replyDraft
        }

        replyViewController.delegate = self
        let frame = CGRect(x: 0.0, y: 0.0, width: replyViewController.view.bounds.width, height: 35.0)
        replyViewController.accessoryView = ReplyAccessoryView(frame: frame, withComposeViewController: replyViewController)
        ReplyAccessoryView.resetTextViewStyle(replyViewController.textView)

        present(replyViewController, animated: true, completion: nil)
    }
}

// MARK: - Network (view model)
extension S1ContentViewController {
    func fetchContentForCurrentPage(forceUpdate: Bool) {
        updateToolBar()

        userActivity?.needsSave = true

        // remove cache for last page
        if forceUpdate {
            viewModel.dataCenter.removePrecachedFloors(for: viewModel.topic, withPage: NSNumber(value: viewModel.currentPage))
        }

        // Set up HUD
        DDLogVerbose("[ContentVC] check precache exist")

        if !viewModel.dataCenter.hasPrecacheFloors(for: viewModel.topic, withPage: NSNumber(value: viewModel.currentPage)) {
            // only show hud when no cached floors
            DDLogVerbose("[ContentVC] Show HUD")
            refreshHUD.showActivityIndicator()

            refreshHUD.refreshEventHandler = { [weak self] (hud) in
                guard let strongSelf = self else { return }

                hud?.hide(withDelay: 0.0)
                strongSelf.fetchContentForCurrentPage(forceUpdate: false)
            }
        }

        viewModel.contentPage(success: { [weak self] (contents, shouldRefetch) in
            guard let strongSelf = self else { return }

            strongSelf.updateToolBar()
            if let title = strongSelf.viewModel.topic.title {
                strongSelf.updateTitleLabel(title: title)
            }

            strongSelf.saveViewPositionForPreviousPage()
            strongSelf.finishFirstLoading = true
            strongSelf.webView.loadHTMLString(contents, baseURL: S1ContentViewModel.pageBaseURL())

            // Prepare next page
            if (!strongSelf._isInLastPage()) && UserDefaults.standard.bool(forKey: "PrecacheNextPage") {
                strongSelf.viewModel.dataCenter.setFinishHandlerFor(strongSelf.viewModel.topic, withPage: NSNumber(value: strongSelf.viewModel.currentPage + 1), andHandler: { [weak self] (floorList) in
                    guard let strongSelf = self else { return }
                    strongSelf.updateToolBar()
                })
                strongSelf.viewModel.dataCenter.precacheFloors(for: strongSelf.viewModel.topic, withPage: NSNumber(value: strongSelf.viewModel.currentPage + 1), shouldUpdate: false)
            }

            // Dismiss HUD if exist
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.hideHUDIfNoMessageToShow()
            }

            // Auto refresh when current page not full.
            if shouldRefetch {
                strongSelf.scrollType = .restorePosition
                strongSelf.fetchContentForCurrentPage(forceUpdate: true)
            }

        }) { [weak self] (error) in
            guard let strongSelf = self else { return }

            if (error as NSError).code == NSURLErrorCancelled {
                DDLogDebug("request cancelled.")
                // TODO:
                //            if (strongSelf.refreshHUD != nil) {
                //                [strongSelf.refreshHUD hideWithDelay:0.3];
                //            }
            } else {
                DDLogDebug("[ContentVC] fetch failed with error: \(error)")
                strongSelf.refreshHUD.showRefreshButton()
            }
        }
    }
}

// MARK: Helper (view model)
extension S1ContentViewController {
    func _isInFirstPage() -> Bool {
        return viewModel.currentPage == 1
    }
    func _isInLastPage() -> Bool {
        return viewModel.currentPage >= viewModel.totalPages
    }
}

// MARK: Helper (hook)
extension S1ContentViewController {
    func _hook_preChangeCurrentPage() {
        DDLogDebug("[webView] pre change current page")

        cancelRequest()
        saveViewPositionForCurrentPage()

        webPageReadyForAutomaticScrolling = false
        webPageSizeChangedForAutomaticScrolling = false
        webPageAutomaticScrollingEnabled = true
    }

    func _hook_preLoadNextPage() {
        // Noting to do
    }

    func _hook_didFinishBasicPageLoad(for webView: WKWebView) {
        DDLogDebug("[webView] basic page loaded")
        let maxOffset = webView.scrollView.contentSize.height - webView.scrollView.bounds.height

        switch scrollType {
        case .pullUpForNext:
            // Set position
            webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: -webView.bounds.height), animated: false)
            // Animated scroll
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseOut, animations: {
                webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
                webView.scrollView.alpha = 1.0
            }, completion: nil)
        case .pullDownForPrevious:
            // Set position
            webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: webView.scrollView.contentSize.height), animated: false)
            // Animated scroll
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseOut, animations: {
                webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: maxOffset), animated: false)
                webView.scrollView.alpha = 1.0
            }, completion: nil)
        case .toBottom:
            webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: maxOffset), animated: true)
        default:
            break
        }
    }

    func _hook_didFinishFullPageLoad(for webView: WKWebView) {
        DDLogDebug("[webView] full page loaded")
        let maxOffset = webView.scrollView.contentSize.height - webView.scrollView.bounds.height
        switch scrollType {
        case .toBottom:
            fallthrough
        case .pullDownForPrevious:
            webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: maxOffset), animated: false)
        case .pullUpForNext:
            webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
        default:
            if let positionForPage = viewModel.cachedOffsetForCurrentPage() {
                // Restore last view position from cached position in this view controller.
                let offset = CGPoint(x: webView.scrollView.contentOffset.x, y: max(min(maxOffset, CGFloat(positionForPage.doubleValue)), 0.0))
                webView.scrollView.setContentOffset(offset, animated: false)
            }
        }

        scrollType = .restorePosition
    }
}

// MARK: Helper (Misc)
extension S1ContentViewController {
    func updateToolBar() {
        func updateForwardButton() {
            // FIXME: this will make state failed to reflect button image but will lead to less quest for cache database which is good.
            forwardButton.setImage(viewModel.forwardButtonImage(), for: .normal)
        }

        func updateBackwardButton() {
            // FIXME: this will make state failed to reflect button image but will lead to less quest for cache database which is good.
            backButton.setImage(viewModel.backwardButtonImage(), for: .normal)
        }

        updateForwardButton()
        updateBackwardButton()
    }

    func updateTitleLabel(title: String) {
        // FIXME: title label should be change by monitoring viewmodel's property change, not by manually call this method
        titleLabel.text = title
        titleLabel.textColor = APColorManager.shared.colorForKey("content.titlelabel.text.normal")
    }

    func _updateDecorationLines(contentSize: CGSize) {
        // Seems no more necessary if we use auto layout
//        self.topDecorateLine.frame = CGRectMake(0, topOffset, contentSize.width, 1);
//        self.bottomDecorateLine.frame = CGRectMake(0, contentSize.height + bottomOffset, contentSize.width, 1);

        topDecorateLine.isHidden = _isInFirstPage() || !self.finishFirstLoading
        bottomDecorateLine.isHidden = !self.finishFirstLoading
    }

    static func positionOfElement(with ID: String, in webView: WKWebView) -> CGRect {
        let script = "function f(){ var r = document.getElementById('\(ID)').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();"
        var rect = CGRect.zero
        let semaphore = DispatchSemaphore(value: 1)
        webView.evaluateJavaScript(script) { (result, error) in
            defer {
                semaphore.signal()
            }

            guard error == nil else {
                DDLogWarn("failed to get position of element: \(ID) with error: \(error)")
                return
            }

            guard let resultString = result as? String else {
                DDLogWarn("failed to get position of element: \(ID) with result: \(result)")
                return
            }

            rect = CGRectFromString(resultString)
        }

        semaphore.wait()
        return rect
    }

    func saveViewPositionForCurrentPage() {
        guard webView.scrollView.contentOffset.y != 0 else {
            return
        }

        viewModel.cacheOffsetForCurrentPage(webView.scrollView.contentOffset.y)
    }

    func saveViewPositionForPreviousPage() {
        guard webView.scrollView.contentOffset.y != 0 else {
            return
        }

        viewModel.cacheOffsetForPreviousPage(webView.scrollView.contentOffset.y)
    }

    func shouldPresentingFavoriteButtonOnToolBar() -> Bool {
        return view.bounds.width > 320.0 + 1.0
    }

    func hideHUDIfNoMessageToShow() {
        if let message = viewModel.topic.message, message != "" {
            refreshHUD.showMessage(message)
            refreshHUD.hide(withDelay: 3.0)
        } else {
            refreshHUD.hide(withDelay: 0.3)
        }
    }

    func forceRefreshCurrentPage() {
        cancelRequest()
        saveViewPositionForCurrentPage()

        fetchContentForCurrentPage(forceUpdate: true)
    }

    func cancelRequest() {
        viewModel.dataCenter.cancelRequest()
    }
}

// MARK: State
extension S1ContentViewController {
    enum ScrollType {
        case restorePosition
        case pullUpForNext
        case pullDownForPrevious
        case toBottom
    }

    enum BackButtonState {
        case back(rotateAngle: Double)
        case cachedBack(rotateAngle: Double)
    }

    enum ForwardButtonState {
        case forward(rotateAngle: Double)
        case cachedForward(rotateAngle: Double)
        case refresh(rotateAngle: Double)
    }
}
