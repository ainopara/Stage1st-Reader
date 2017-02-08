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
import JTSImageViewController
import Crashlytics
import ReactiveSwift
import ReactiveCocoa
import Photos

private let topOffset: CGFloat = -80.0
private let bottomOffset: CGFloat = 60.0
private let blankPageHTMLString = "<!DOCTYPE html> <html><head><meta http-equiv=\"Content-Type\" content=\"text/html;\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\"></head><body style=\" height: 1px; width: 1px\"></body></html>"

class S1ContentViewController: UIViewController, ImagePresenter, UserPresenter, ContentPresenter, QuoteFloorPresenter {
    let viewModel: S1ContentViewModel

    var toolBar = UIToolbar(frame: .zero)
    lazy var webView: WKWebView = {
        return WKWebView(frame: .zero, configuration: self.sharedWKWebViewConfiguration())
    }()

    lazy var webViewScriptMessageHandler: GeneralScriptMessageHandler = {
        return GeneralScriptMessageHandler(delegate: self)
    }()

    lazy var pullToActionController: PullToActionController = {
        return PullToActionController(scrollView: self.webView.scrollView)
    }()

    var refreshHUD = S1HUD(frame: .zero)
    var hintHUD = S1HUD(frame: .zero)

    var backButton = UIButton(type: .system)
    var forwardButton = UIButton(type: .system)
    var pageButton = UIButton(frame: .zero)
    var favoriteButton = UIButton(type: .system)
    lazy var actionBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(action(sender:)))
    }()

    var titleLabel = UILabel(frame: .zero)
    var topDecorateLine = UIView(frame: .zero)
    var bottomDecorateLine = UIView(frame: .zero)

    var attributedReplyDraft: NSMutableAttributedString?
    weak var replyTopicFloor: Floor?

    var scrollType: ScrollType = .restorePosition {
        didSet {
            DDLogInfo("[ContentVC] scroll type changed: \(oldValue.rawValue) -> \(scrollType.rawValue)")
        }
    }

    var backButtonState: BackButtonState = .back(rotateAngle: 0.0) {
        didSet {
            switch backButtonState {
            case .back(let rotateAngle):
                if case .back(let oldRotateAngle) = oldValue {
                    if rotateAngle != oldRotateAngle {
                        backButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(M_PI_2 * rotateAngle), 0.0, 0.0, 1.0)
                    }
                } else {
                    backButton.setImage(viewModel.backwardButtonImage(), for: .normal)
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
                    forwardButton.setImage(viewModel.forwardButtonImage(), for: .normal)
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

    let finishFirstLoading = MutableProperty(false) // No automatic scrolling should happen before first loading.
    let webPageReadyForAutomaticScrolling = MutableProperty(false) // No automatic scrolling should happen before content ready. ready signal will trigger first automatic scrolling.
    let webPageCurrentContentHeight = MutableProperty(0.0 as CGFloat) // Every content height change will trying to trigger automatic scrolling.

    var webPageAutomaticScrollingEnabled = true // Note: User interaction will disable automatic scrolling.
    var webPageDidFinishFirstAutomaticScrolling = false // Note: Only first automatic scrolling has animation.

    var presentType: PresentType = .none {
        didSet {
            switch presentType {
            case .none:
                Crashlytics.sharedInstance().setObjectValue("ContentViewController", forKey: "lastViewController")
            case .image:
                Crashlytics.sharedInstance().setObjectValue("ImageViewController", forKey: "lastViewController")
            case .web:
                Crashlytics.sharedInstance().setObjectValue("WebViewer", forKey: "lastViewController")
            default:
                break
            }
        }
    }

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
        backButton.imageView?.clipsToBounds = false
        backButton.imageView?.contentMode = .center
        backButton.addTarget(self, action: #selector(back(sender:)), for: .touchUpInside)
        let backLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(backLongPressed(gestureRecognizer:)))
        backLongPressGestureRecognizer.minimumPressDuration = 0.5
        backButton.addGestureRecognizer(backLongPressGestureRecognizer)

        // Forward button
        let image = viewModel.isInLastPage() ? #imageLiteral(resourceName: "Refresh_black") : #imageLiteral(resourceName: "Forward")
        forwardButton.setImage(image, for: .normal)
        forwardButton.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 30.0)
        forwardButton.imageView?.clipsToBounds = false
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
        webView.loadHTMLString(blankPageHTMLString, baseURL: URL(string: "about:blank"))

        // Decoration line
        topDecorateLine.isHidden = true
        bottomDecorateLine.isHidden = true

        // Pull to action
        pullToActionController.addObservation(withName: "top", baseLine: .top, beginPosition: 0.0, endPosition: Double(topOffset))
        pullToActionController.addObservation(withName: "bottom", baseLine: .bottom, beginPosition: 0.0, endPosition: Double(bottomOffset))
        pullToActionController.delegate = self

        // Title label
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .center

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

        toolBar.setItems([
            backwardItem,
            fixItem,
            forwardItem,
            flexItem,
            labelItem,
            flexItem,
            favoriteItem,
            fixItem2,
            actionBarButtonItem
            ], animated: false)

        // Binding
        viewModel.currentPage.producer
            .combineLatest(with: viewModel.totalPages.producer)
            .startWithValues { [weak self] (currentPage, totalPage) in
            DDLogVerbose("[ContentVM] Current page or totoal page changed: \(currentPage)/\(totalPage)")
            guard let strongSelf = self else { return }
            strongSelf.pageButton.setTitle(strongSelf.viewModel.pageButtonString(), for: .normal)
        }

        SignalProducer
            .combineLatest(webPageReadyForAutomaticScrolling.producer, webPageCurrentContentHeight.producer)
            .startWithValues { [weak self] (webPageReady, currentHeight) in

            guard let strongSelf = self else { return }
            let finishFirstLoading = strongSelf.finishFirstLoading.value
            DDLogVerbose("[ContentVC] document ready: \(webPageReady), finish first loading: \(finishFirstLoading), current height: \(currentHeight), scrolling enable: \(strongSelf.webPageAutomaticScrollingEnabled)")

            if webPageReady && finishFirstLoading && strongSelf.webPageAutomaticScrollingEnabled {
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf._hook_didFinishBasicPageLoad(for: strongSelf.webView)
                }
            }
        }

        favoriteButton.reactive.controlEvents(.touchUpInside).observeValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.viewModel.toggleFavorite()
        }

        viewModel.favorite.producer
            .take(during: self.reactive.lifetime)
            .map { $0?.boolValue ?? false }
            .startWithValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.favoriteButton.setImage(strongSelf.viewModel.favoriteButtonImage(), for: .normal)
        }

        viewModel.title.producer
            .take(during: self.reactive.lifetime)
            .startWithValues { [weak self] (title) in
            guard let strongSelf = self else { return }
            if let title = title, title != "" {
                strongSelf.titleLabel.text = title as String
                strongSelf.titleLabel.textColor = ColorManager.shared.colorForKey("content.titlelabel.text.normal")
            } else {
                strongSelf.titleLabel.text = "\(strongSelf.viewModel.topic.topicID) 载入中..."
                strongSelf.titleLabel.textColor = ColorManager.shared.colorForKey("content.titlelabel.text.disable")
            }
        }

        // Activity
        _setupActivity()

        // Notification
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: .UIApplicationWillEnterForeground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReceivePaletteChangeNotification(_:)),
                                               name: .APPaletteDidChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReceiveFloorCachedNotification(_:)),
                                               name: Notification.Name(rawValue: "S1FloorDidCached"),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReceiveUserBlockStatusDidChangedNotification(_:)),
                                               name: .UserBlockStatusDidChangedNotification,
                                               object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        DDLogInfo("[ContentVC] Dealloc Begin")
        NotificationCenter.default.removeObserver(self)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "stage1st")
        pullToActionController.stop()
        webView.stopLoading()
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

        presentType = .none

        // defer from initializer to here to make sure navigationController exist (i.e. self be added to navigation stack)
        // FIXME: find a way to make sure this only called once. Prefer this not work.
        if let colorPanRecognizer = (self.navigationController?.delegate as? NavigationControllerDelegate)?.colorPanRecognizer {
            webView.scrollView.panGestureRecognizer.require(toFail: colorPanRecognizer)
        }

        didReceivePaletteChangeNotification(nil)

        // Also use this method to initialize content.
        _tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        guard case .none = presentType else {
            return
        }

        viewModel.cancelRequest()
        saveTopicViewedState(sender: nil)
        DDLogDebug("[ContentVC] View did disappear end")
    }

    func applicationWillEnterForeground() {
        DDLogDebug("[ContentVC] \(self) will enter foreground begin")
        _tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated()
    }

    func applicationDidEnterBackground() {
        DDLogDebug("[ContentVC] \(self) did enter background begin")
        saveTopicViewedState(sender: nil)
        DDLogDebug("[ContentVC] \(self) did enter background end")
    }
}

// MARK: - Actions
extension S1ContentViewController {
    open func back(sender: Any?) {
        if viewModel.isInFirstPage() {
            _ = navigationController?.popViewController(animated: true)
        } else {
            if let _ = sender as? WKWebView {
                scrollType = .pullDownForPrevious
            } else {
                scrollType = .restorePosition
            }
            _hook_preChangeCurrentPage()
            viewModel.currentPage.value -= 1
            fetchContentForCurrentPage(forceUpdate: false)
        }
    }

    open func forward(sender: Any?) {
        switch (viewModel.isInLastPage(), self.webView.s1_atBottom()) {
        case (true, false):
            webView.s1_scrollToBottom(animated: true)
        case (true, true):
            refreshCurrentPage(forceUpdate: true, scrollType: .restorePosition)
        case (false, _):
            if let _ = sender as? WKWebView {
                scrollType = .pullUpForNext
            } else {
                scrollType = .restorePosition
            }
            _hook_preChangeCurrentPage()
            viewModel.currentPage.value += 1
            fetchContentForCurrentPage(forceUpdate: false)
        default:
            DDLogError("This should never happen, just make swift compiler happy.")
        }
    }

    open func backLongPressed(gestureRecognizer: UIGestureRecognizer) {
        guard
            gestureRecognizer.state == UIGestureRecognizerState.began,
            !viewModel.isInFirstPage() else {
            return
        }

        scrollType = .restorePosition
        _hook_preChangeCurrentPage()
        viewModel.currentPage.value = 1
        fetchContentForCurrentPage(forceUpdate: false)
    }

    open func forwardLongPressed(gestureRecognizer: UIGestureRecognizer) {
        guard
            gestureRecognizer.state == UIGestureRecognizerState.began,
            !viewModel.isInLastPage() else {
            return
        }

        scrollType = .restorePosition
        _hook_preChangeCurrentPage()
        viewModel.currentPage.value = viewModel.totalPages.value
        fetchContentForCurrentPage(forceUpdate: false)
    }

    open func pickPage(sender: Any?) {
        func generatePageList() -> [String] {
            var pageList = [String]()

            for page in 1...max(viewModel.currentPage.value, viewModel.totalPages.value) {
                if viewModel.dataCenter.hasPrecacheFloors(for: viewModel.topic, withPage: NSNumber(value: page)) {
                    pageList.append("✓第 \(page) 页✓")
                } else {
                    pageList.append("第 \(page) 页")
                }
            }

            return pageList
        }

        let pageList = generatePageList()

        let picker = ActionSheetStringPicker(title: "",
                                             rows: pageList,
                                             initialSelection: Int(viewModel.currentPage.value - 1),
                                             doneBlock: { [weak self] (_, selectedIndex, _) in
            guard let strongSelf = self else { return }

            if strongSelf.viewModel.currentPage.value == UInt(selectedIndex + 1) {
                strongSelf.refreshCurrentPage(forceUpdate: true, scrollType: .restorePosition)
            } else {
                strongSelf.scrollType = .restorePosition
                strongSelf._hook_preChangeCurrentPage()
                strongSelf.viewModel.currentPage.value = UInt(selectedIndex + 1)
                strongSelf.fetchContentForCurrentPage(forceUpdate: false)
            }
        }, cancel: nil, origin: pageButton)

        picker?.pickerBackgroundColor = ColorManager.shared.colorForKey("content.picker.background")
        picker?.toolbarBackgroundColor = ColorManager.shared.colorForKey("appearance.toolbar.bartint")
        picker?.toolbarButtonsColor = ColorManager.shared.colorForKey("appearance.toolbar.tint")

        let labelParagraphStyle = NSMutableParagraphStyle()
        labelParagraphStyle.alignment = .center
        picker?.pickerTextAttributes = [
            NSParagraphStyleAttributeName: labelParagraphStyle,
            NSFontAttributeName: UIFont.systemFont(ofSize: 19.0),
            NSForegroundColorAttributeName: ColorManager.shared.colorForKey("content.picker.text")
        ]
        picker?.show()
    }

    open func forceRefreshPressed(gestureRecognizer: UIGestureRecognizer) {
        guard gestureRecognizer.state == .began else {
            return
        }

        DDLogDebug("[ContentVC] Force refresh pressed")
        refreshCurrentPage(forceUpdate: true, scrollType: .restorePosition)
    }

    open func action(sender: Any?) {
        let moreActionSheet = UIAlertController(title: nil,
                                                message: nil,
                                                preferredStyle: .actionSheet)

        // Reply Action
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentView_ActionSheet_Reply", comment: "Reply"),
                                                style: .default,
                                                handler: { [weak self] (_) in
            guard let strongSelf = self else { return }
            guard strongSelf.viewModel.topic.fID != nil, strongSelf.viewModel.topic.formhash != nil else {
                Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                    "type": "ReplyTopic",
                    "source": "Content",
                    "result": "Failed"
                ])
                strongSelf._alertRefresh()
                return
            }

            guard UserDefaults.standard.object(forKey: "InLoginStateID") as? String != nil else {
                Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                    "type": "ReplyTopic",
                    "source": "Content",
                    "result": "Failed"
                ])
                let loginViewController = S1LoginViewController(nibName: nil, bundle: nil)
                strongSelf.present(loginViewController, animated: true, completion: nil)
                return
            }

            Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                "type": "ReplyTopic",
                "source": "Content",
                "result": "Succeeded"
            ])
            strongSelf._presentReplyView(toFloor: nil)
        }))

        if !shouldPresentingFavoriteButtonOnToolBar() {
            // Favorite Action
            let title = viewModel.topic.favorite?.boolValue ?? false ? NSLocalizedString("ContentView_ActionSheet_Cancel_Favorite", comment: "Cancel Favorite") : NSLocalizedString("ContentView_ActionSheet_Favorite", comment: "Favorite")
            moreActionSheet.addAction(UIAlertAction(title: title,
                                                    style: .default,
                                                    handler: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.viewModel.toggleFavorite()
                let message = strongSelf.viewModel.topic.favorite?.boolValue ?? false ? NSLocalizedString("ContentView_ActionSheet_Favorite", comment: "Favorite") : NSLocalizedString("ContentView_ActionSheet_Cancel_Favorite", comment: "Cancel Favorite")
                strongSelf.hintHUD.showMessage(message)
                strongSelf.hintHUD.hide(withDelay: 0.5)
            }))
        }

        // Share Action
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentView_ActionSheet_Share", comment: "Share"),
                                                style: .default,
                                                handler: { [weak self] (_) in
            guard let strongSelf = self else { return }

            let rect = mutate(strongSelf.view.bounds) { (value: inout CGRect) in
                value.origin.y += 20.0
                value.size.height -= 20.0
            }

            let items: [Any] = ([
                ContentTextActivityItemProvider(title: strongSelf.viewModel.topic.title ?? ""),
                strongSelf.viewModel.correspondingWebPageURL(),
                ContentImageActivityItemProvider(view: strongSelf.view, cropTo: rect)] as [Any?])
                .flatMap { $0 }

            let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
            activityController.popoverPresentationController?.barButtonItem = strongSelf.actionBarButtonItem

            Answers.logCustomEvent(withName: "Share", customAttributes: [
                "object": "Topic",
                "source": "Content"
            ])
            strongSelf.present(activityController, animated: true, completion: nil)
        }))

        // Copy Link
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentView_ActionSheet_CopyLink", comment: "Copy Link"),
                                                style: .default,
                                                handler: { [weak self] (_) in
            guard let strongSelf = self else { return }
            if let urlString = strongSelf.viewModel.correspondingWebPageURL()?.absoluteString {
                UIPasteboard.general.string = urlString
                strongSelf.hintHUD.showMessage(NSLocalizedString("ContentView_ActionSheet_CopyLink", comment: "Copy Link"))
                strongSelf.hintHUD.hide(withDelay: 0.3)
            } else {
                DDLogWarn("[ContentVC] can not generate corresponding web page url.")
            }
        }))

        // Origin Page Action
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentView_ActionSheet_OriginPage", comment: "Origin"),
                                                style: .default,
                                                handler: { [weak self] (_) in
            guard let strongSelf = self else { return }
            if let urlToOpen = strongSelf.viewModel.correspondingWebPageURL() {
                let webViewController = WebViewController(URL: urlToOpen)
                strongSelf.present(webViewController, animated: true, completion: nil)
            } else {
                DDLogWarn("[ContentVC] can not generate corresponding web page url.")
            }
        }))

        // Cancel Action
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentView_ActionSheet_Cancel", comment: "Cancel"),
                                                style: .cancel,
                                                handler: nil))

        moreActionSheet.popoverPresentationController?.barButtonItem = self.actionBarButtonItem
        present(moreActionSheet, animated: true, completion: nil)
    }

    open func actionButtonTapped(for floorID: Int) {
        guard let floor = viewModel.searchFloorInCache(floorID) else {
            return
        }

        DDLogDebug("[ContentVC] Action for \(floor)")
        let floorActionController = UIAlertController(title: nil,
                                                      message: nil,
                                                      preferredStyle: .actionSheet)

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Report", comment: ""), style: .destructive, handler: { [weak self] (_) in
            guard let strongSelf = self else { return }
            guard strongSelf.viewModel.topic.formhash != nil && strongSelf.viewModel.topic.fID != nil else {
                Answers.logCustomEvent(withName: "Click Report", customAttributes: [
                    "source": "Content",
                    "result": "Failed"
                ])
                strongSelf._alertRefresh()
                return
            }

            guard UserDefaults.standard.object(forKey: "InLoginStateID") as? String != nil else {
                Answers.logCustomEvent(withName: "Click Report", customAttributes: [
                    "source": "Content",
                    "result": "Failed"
                ])
                let loginViewController = S1LoginViewController(nibName: nil, bundle: nil)
                strongSelf.present(loginViewController, animated: true, completion: nil)
                return
            }

            Answers.logCustomEvent(withName: "Click Report", customAttributes: [
                "source": "Content",
                "result": "Succeeded"
            ])
            strongSelf.presentType = .report
            let reportViewModel = strongSelf.viewModel.reportComposeViewModel(floor: floor)
            let reportComposeViewController = ReportComposeViewController(viewModel: reportViewModel)
            strongSelf.present(UINavigationController(rootViewController: reportComposeViewController), animated: true, completion: nil)
        }))

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Reply", comment: ""), style: .default, handler: { [weak self] (_) in
            guard let strongSelf = self else { return }
            guard strongSelf.viewModel.topic.formhash != nil && strongSelf.viewModel.topic.fID != nil else {
                Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                    "type": "ReplyFloor",
                    "source": "Content",
                    "result": "Failed"
                ])
                strongSelf._alertRefresh()
                return
            }

            guard UserDefaults.standard.object(forKey: "InLoginStateID") as? String != nil else {
                Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                    "type": "ReplyFloor",
                    "source": "Content",
                    "result": "Failed"
                ])
                let loginViewController = S1LoginViewController(nibName: nil, bundle: nil)
                strongSelf.present(loginViewController, animated: true, completion: nil)
                return
            }

            Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                "type": "ReplyFloor",
                "source": "Content",
                "result": "Succeeded"
            ])
            strongSelf._presentReplyView(toFloor: floor)
        }))

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("S1ContentViewController.FloorActionSheet.Cancel", comment: ""), style: .cancel, handler: nil))

        if let popover = floorActionController.popoverPresentationController {
            popover.delegate = self
            DispatchQueue.global(qos: .default).async { [weak self] in
                guard let strongSelf = self else { return }
                popover.sourceView = strongSelf.webView
                popover.sourceRect = strongSelf.webView.s1_positionOfElement(with: "\(floorID)-action") ?? CGRect(origin: strongSelf.webView.center, size: .zero)
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.present(floorActionController, animated: true, completion: nil)
                }
            }
        } else {
            present(floorActionController, animated: true, completion: nil)
        }
    }

    func _alertRefresh() {
        let refreshAlertController = UIAlertController(title: "缺少必要的信息",
                                                       message: "请长按页码刷新当前页面",
                                                       preferredStyle: .alert)
        refreshAlertController.addAction(UIAlertAction(title: "好",
                                                       style: .cancel,
                                                       handler: nil))
        present(refreshAlertController, animated: true, completion: nil)
    }

    open func saveTopicViewedState(sender: Any?) {
        if finishFirstLoading.value {
            viewModel.saveTopicViewedState(lastViewedPosition: Double(webView.scrollView.contentOffset.y))
        } else {
            viewModel.saveTopicViewedState(lastViewedPosition: nil)
        }
    }

    open override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        // Color
        view.backgroundColor = ColorManager.shared.colorForKey("content.background")
        webView.backgroundColor = ColorManager.shared.colorForKey("content.webview.background")
        webView.scrollView.indicatorStyle = ColorManager.shared.isDarkTheme() ? .white : .default
        topDecorateLine.backgroundColor = ColorManager.shared.colorForKey("content.decoration.line")
        bottomDecorateLine.backgroundColor = ColorManager.shared.colorForKey("content.decoration.line")
        if let title = self.viewModel.topic.title, title != "" {
            titleLabel.textColor = ColorManager.shared.colorForKey("content.titlelabel.text.normal")
        } else {
            titleLabel.textColor = ColorManager.shared.colorForKey("content.titlelabel.text.disable")
        }
        pageButton.setTitleColor(ColorManager.shared.colorForKey("content.pagebutton.text"), for: .normal)
        toolBar.barTintColor = ColorManager.shared.colorForKey("appearance.toolbar.bartint")
        toolBar.tintColor = ColorManager.shared.colorForKey("appearance.toolbar.tint")

        setNeedsStatusBarAppearanceUpdate()

        if notification != nil {
            saveViewPositionForCurrentPage()
            refreshCurrentPage(forceUpdate: false, scrollType: .restorePosition)
        }
    }

    open func didReceiveFloorCachedNotification(_ notification: Notification?) {
        guard
            let topicID = notification?.userInfo?["topicID"] as? NSNumber,
            let page = notification?.userInfo?["page"] as? NSNumber,
            viewModel.topic.topicID.intValue == topicID.intValue,
            page.intValue - Int(viewModel.currentPage.value) == 1 else {
            return
        }

        updateToolBar()
    }

    open func didReceiveUserBlockStatusDidChangedNotification(_ notification: Notification?) {
      refreshCurrentPage(forceUpdate: false, scrollType: .restorePosition)
    }
}

// MARK: -
// MARK: WKNavigationDelegate
extension S1ContentViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DDLogInfo("[ContentVC] webViewDidFinishLoad")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DDLogWarn("[ContentVC] webview failed to load with error: \(error)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        DDLogError("[ContentVC] webViewWebContentProcessDidTerminate")
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

        if url.absoluteString.hasPrefix("file://") && url.absoluteString.hasSuffix("html") {
            decisionHandler(.allow)
            return
        }

        // Image URL opened in image Viewer
        if url.absoluteString.hasSuffix(".jpg") || url.absoluteString.hasSuffix(".gif") || url.absoluteString.hasSuffix(".png") {
            Answers.logCustomEvent(withName: "Inspect Image", customAttributes: [
                "type": "Hijack",
                "source": "Content"
            ])
            showImageViewController(transitionSource: .offScreen, imageURL: url)
            decisionHandler(.cancel)
            return
        }

        if let baseURL = UserDefaults.standard.string(forKey: "BaseURL"), url.absoluteString.hasPrefix(baseURL) {
            // Open as S1 topic
            if let topic = S1Parser.extractTopicInfo(fromLink: url.absoluteString) {
                // TODO: Make this logic easy to understand.
                var topic = topic
                if let tracedTopic = viewModel.dataCenter.tracedTopic(topic.topicID) {
                    let lastViewedPage = topic.lastViewedPage
                    topic = tracedTopic.copy() as! S1Topic
                    if lastViewedPage != nil {
                        topic.lastViewedPage = lastViewedPage
                    }
                }

                Answers.logCustomEvent(withName: "Open Topic Link", customAttributes: [
                    "source": "Content"
                ])
                showContentViewController(topic: topic)
                decisionHandler(.cancel)
                return
            }

            // Open Quote Link
            if let querys = S1Parser.extractQuerys(fromURLString: url.absoluteString),
               let mod = querys["mod"], mod == "redirect",
               let tidString = querys["ptid"],
               let tid = Int(tidString), tid == viewModel.topic.topicID.intValue,
               let pidString = querys["pid"],
               let pid = Int(pidString),
               let chainQuoteFloors = Optional.some(viewModel.chainSearchQuoteFloorInCache(pid)), chainQuoteFloors.count > 0 {
                Answers.logCustomEvent(withName: "Open Quote Link", customAttributes: [
                    "source": "Content"
                ])
                showQuoteFloorViewController(floors: chainQuoteFloors, centerFloorID: chainQuoteFloors.last!.ID)
                decisionHandler(.cancel)
                return
            }
        }

        // Fallback Open link
        let alertViewController = UIAlertController(title: NSLocalizedString("ContentView_WebView_Open_Link_Alert_Title", comment: ""), message: url.absoluteString, preferredStyle: .alert)
        alertViewController.addAction(UIAlertAction(title: NSLocalizedString("ContentView_WebView_Open_Link_Alert_Cancel", comment: ""), style: .cancel, handler: nil))
        alertViewController.addAction(UIAlertAction(title: NSLocalizedString("ContentView_WebView_Open_Link_Alert_Open", comment: ""), style: .default, handler: { (_) in
            DDLogInfo("[ContentVC] Open in Safari: \(url)")

            if !UIApplication.shared.openURL(url) {
                DDLogWarn("Failed to open url: \(url)")
            }
        }))

        present(alertViewController, animated: true, completion: nil)

        DDLogWarn("No case match for url: \(url), fallback to asking for open link.")
        decisionHandler(.cancel)
        return
    }
}
// MARK: - WebViewEventDelegate
extension S1ContentViewController: WebViewEventDelegate {
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, readyWith messageDictionary: [String : Any]) {
        webPageReadyForAutomaticScrolling.value = true
    }

    func generalScriptMessageHandlerTouchEvent(_ scriptMessageHandler: GeneralScriptMessageHandler) {
        if webPageDidFinishFirstAutomaticScrolling && webPageAutomaticScrollingEnabled {
            DDLogInfo("User Touch detected. Stop tracking scroll type \(scrollType)")
            webPageAutomaticScrollingEnabled = false
        }
    }

    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, actionButtonTappedFor floorID: Int) {
        actionButtonTapped(for: floorID)
    }
}

extension S1ContentViewController {
    func sharedWKWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(webViewScriptMessageHandler, name: "stage1st")
        configuration.userContentController = userContentController
        return configuration
    }
}

// MARK: - JTSImageViewControllerInteractionsDelegate
extension S1ContentViewController: JTSImageViewControllerInteractionsDelegate {
    func imageViewerDidLongPress(_ imageViewer: JTSImageViewController!, at rect: CGRect) {
        let imageActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        imageActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ImageViewer_ActionSheet_Save", comment: "Save"), style: .default, handler: { (_) in
            DispatchQueue.global(qos: .background).async {
                PHPhotoLibrary.requestAuthorization { status in
                    guard case .authorized = status else {
                        DDLogError("No auth to access photo library")
                        return
                    }

                    let imageData = imageViewer.imageData
                    guard imageData != nil else {
                        DDLogError("Image data is nil")
                        return
                    }

                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData!, options: nil)
                    }, completionHandler: { (_, error) in
                        if let error = error {
                            DDLogError("\(error)")
                        }
                    })
                }
            }
        }))

        imageActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ImageViewer_ActionSheet_CopyURL", comment: "Copy URL"), style: .default, handler: { (_) in
            UIPasteboard.general.string = imageViewer.imageInfo.imageURL.absoluteString
        }))

        imageActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentView_ActionSheet_Cancel", comment: "Cancel"), style: .cancel, handler: nil))

        imageActionSheet.popoverPresentationController?.sourceView = imageViewer.view
        imageActionSheet.popoverPresentationController?.sourceRect = rect
        imageViewer.present(imageActionSheet, animated: true, completion: nil)
    }
}

// MARK: JTSImageViewControllerOptionsDelegate
extension S1ContentViewController: JTSImageViewControllerOptionsDelegate {
    func alphaForBackgroundDimmingOverlay(inImageViewer imageViewer: JTSImageViewController!) -> CGFloat {
        return 0.3
    }
}

// MARK: - PullToActionDelagete
extension S1ContentViewController: PullToActionDelagete {

    // To fix bug in WKWebView
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
    }

    public func scrollViewDidEndDraggingOutsideTopBound(with offset: CGFloat) {
        guard
            offset < topOffset,
            self.finishFirstLoading.value,
            !self.viewModel.isInFirstPage() else {
            return
        }

        var currentContentOffset = self.webView.scrollView.contentOffset
//        currentContentOffset.y = -self.webView.bounds.height
        currentContentOffset.y -= self.webView.bounds.height / 2

        // DIRTYHACK: delay 0.01 second to avoid animation to overrided by other animation setted by iOS
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.webView.scrollView.setContentOffset(currentContentOffset, animated: false)
                strongSelf.webView.scrollView.alpha = 0.0
            }, completion: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.back(sender: strongSelf.webView)
            })
        }
    }

    public func scrollViewDidEndDraggingOutsideBottomBound(with offset: CGFloat) {
        guard
            offset > bottomOffset,
            self.finishFirstLoading.value else {
            return
        }

        guard !self.viewModel.isInLastPage() else {
            // Only refresh triggered in last page
            self.forward(sender: nil)
            return
        }

        var currentContentOffset = self.webView.scrollView.contentOffset
//        currentContentOffset.y = self.webView.scrollView.contentSize.height
        currentContentOffset.y += self.webView.bounds.height / 2

        // DIRTYHACK: delay 0.01 second to avoid animation to overrided by other animation setted by iOS
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.webView.scrollView.setContentOffset(currentContentOffset, animated: false)
                strongSelf.webView.scrollView.alpha = 0.0
            }, completion: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.forward(sender: strongSelf.webView)
            })
        }
    }

    public func scrollViewContentSizeDidChange(_ contentSize: CGSize) {
        _updateDecorationLines(contentSize: contentSize)
        webPageCurrentContentHeight.value = CGFloat(contentSize.height)
    }

    public func scrollViewContentOffsetProgress(_ progress: [String : Double]) {
        guard finishFirstLoading.value else {
            if viewModel.isInLastPage() {
                forwardButtonState = .refresh(rotateAngle: 0.0)
            }
            // back state set depend on cache info
            return
        }

        // Process for bottom offset
        if let bottomProgress = progress["bottom"] {
            if viewModel.isInLastPage() {
                if bottomProgress >= 0 {
                    forwardButtonState = .refresh(rotateAngle: bottomProgress)
                } else {
                    forwardButtonState = .forward(rotateAngle: 1.0)
                }
            } else {
                forwardButtonState = .forward(rotateAngle: max(min(bottomProgress, 1.0), 0.0))
            }
        }

        // Process for top offset
        if let topProgress = progress["top"] {
            if viewModel.isInFirstPage() {
                backButtonState = .back(rotateAngle: 0.0)
            } else {
                backButtonState = .back(rotateAngle: max(min(topProgress, 1.0), 0.0))
            }
        }
    }
}

// MARK: - REComposeViewControllerDelegate
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
                MessageHUD.shared.post(message: "回复成功", duration: .second(2.5))
                guard let strongSelf = self else { return }
                strongSelf.attributedReplyDraft = nil
                if strongSelf.viewModel.isInLastPage() {
                    strongSelf.refreshCurrentPage(forceUpdate: true, scrollType: .toBottom)
                }
            }

            let failureBlock = { (error: Error) in
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    DDLogDebug("[Network] NSURLErrorCancelled")
                    MessageHUD.shared.post(message: "回复请求取消", duration: .second(1.0))
                } else {
                    DDLogDebug("[Network] reply error: \(error)")
                    MessageHUD.shared.post(message: "回复失败", duration: .second(2.5))
                }
            }
            MessageHUD.shared.post(message: "回复发送中", duration: .forever)

            if let replyTopicFloor = replyTopicFloor {
                viewModel.dataCenter.replySpecificFloor(replyTopicFloor, in: viewModel.topic, atPage: NSNumber(value: viewModel.currentPage.value), withText: composeViewController.plainText, success: successBlock, failure: failureBlock)
            } else {
                viewModel.dataCenter.reply(viewModel.topic, withText: composeViewController.plainText, success: successBlock, failure: failureBlock)
            }

            composeViewController.dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension S1ContentViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationController(_ popoverPresentationController: UIPopoverPresentationController, willRepositionPopoverTo rect: UnsafeMutablePointer<CGRect>, in view: AutoreleasingUnsafeMutablePointer<UIView>) {
        // TODO: find a solution.
//        guard case .action(let floorID) = presentType else { return }
//        DispatchQueue.global(qos: .default).async { [weak self] in
//            guard let strongSelf = self else { return }
//            rect.pointee = strongSelf.webView.s1_positionOfElement(with: "\(floorID)-action")
//        }
    }
}

// MARK: - Layout & Style
extension S1ContentViewController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        DDLogDebug("viewWillTransitionToSize: \(size)")

        var frame = view.frame
        frame.size = size
        view.frame = frame

        // Update Toolbar Layout
        if let items = toolBar.items {
            let favoriteItem = items[6]
            let fixItem2 = items[7]
            if shouldPresentingFavoriteButtonOnToolBar() {
                favoriteItem.customView?.bounds = CGRect(x: 0.0, y: 0.0, width: 30.0, height: 40.0)
                favoriteItem.customView?.isHidden = false
                fixItem2.width = 48.0
            } else {
                favoriteItem.customView?.bounds = .zero
                favoriteItem.customView?.isHidden = true
                fixItem2.width = 0.0
            }
        }
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return ColorManager.shared.isDarkTheme() ? .lightContent : .default
    }
}

// MARK: - NSUserActivity (aspect)
extension S1ContentViewController {
    func _setupActivity() {
        DispatchQueue.global().async { [weak self] in
            guard let strongSelf = self else { return }
            let activity = NSUserActivity(activityType: "Stage1st.view-topic")
            activity.title = strongSelf.viewModel.activityTitle()
            activity.userInfo = strongSelf.viewModel.activityUserInfo()
            activity.webpageURL = strongSelf.viewModel.correspondingWebPageURL() as URL?
            activity.isEligibleForSearch = true
            activity.requiredUserInfoKeys = Set(["topicID"])

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

// MARK: - Main Function
extension S1ContentViewController {
    func fetchContentForCurrentPage(forceUpdate: Bool) {
        func showHud() {
            if !viewModel.hasPrecachedCurrentPage() {
                // only show hud when no cached floors
                DDLogVerbose("[ContentVC] check precache: not hit. shows HUD")
                refreshHUD.showActivityIndicator()

                refreshHUD.refreshEventHandler = { [weak self] (hud) in
                    guard let strongSelf = self else { return }

                    hud?.hide(withDelay: 0.0)
                    strongSelf.refreshCurrentPage(forceUpdate: true, scrollType: .restorePosition)
                }
            } else {
                DDLogVerbose("[ContentVC] check precache: hit.")
            }
        }

        updateToolBar()

        userActivity?.needsSave = true

        // remove cache for last page
        if forceUpdate {
            viewModel.dataCenter.removePrecachedFloors(for: viewModel.topic, withPage: NSNumber(value: viewModel.currentPage.value))
        }

        // Set up HUD
        showHud()

        viewModel.currentContentPage { [weak self] (result) in
            guard let strongSelf = self else { return }

            switch result {
            case .success(let contents, let shouldRefetch):
                strongSelf.updateToolBar() /// TODO: Is it still necessary?

                if strongSelf.finishFirstLoading.value {
                    strongSelf.saveViewPositionForPreviousPage()
                }
                strongSelf.finishFirstLoading.value = true
                strongSelf.webView.loadHTMLString(contents, baseURL: S1ContentViewModel.pageBaseURL())

                // Prepare next page
                if (!strongSelf.viewModel.isInLastPage()) && UserDefaults.standard.bool(forKey: "PrecacheNextPage") {
                    strongSelf.viewModel.dataCenter.precacheFloors(for: strongSelf.viewModel.topic, withPage: NSNumber(value: strongSelf.viewModel.currentPage.value + 1), shouldUpdate: false)
                }

                // Dismiss HUD if exist
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.hideHUD()
                }

                // Auto refresh when current page not full.
                if shouldRefetch {
                    strongSelf.refreshCurrentPage(forceUpdate: true, scrollType: .restorePosition)
                }
            case .failure(let error):
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    DDLogDebug("request cancelled.")
                    // TODO:
                    //            if (strongSelf.refreshHUD != nil) {
                    //                [strongSelf.refreshHUD hideWithDelay:0.3];
                    //            }
                } else {
                    let nsError = error as NSError
                    if nsError.domain == "Stage1stErrorDomain" && nsError.code == 101 {
                        DDLogInfo("[ContentVC] Permission denied with message: \(error)")
                        if let message = nsError.userInfo["message"] as? String, message != "" {
                            strongSelf.refreshHUD.showMessage(message)
                            strongSelf.refreshHUD.hide(withDelay: 3.0)
                        }
                    } else {
                        DDLogDebug("[ContentVC] fetch failed with error: \(error)")
                        strongSelf.refreshHUD.showRefreshButton()
                    }
                }
            }
        }
    }

    func _presentReplyView(toFloor floor: Floor?) {
        let replyViewController = REComposeViewController(nibName: nil, bundle: nil)
        replyViewController.delegate = self
        replyViewController.textView.keyboardAppearance = ColorManager.shared.isDarkTheme() ? .dark : .default
        replyViewController.textView.tintColor = ColorManager.shared.colorForKey("reply.tint")
        replyViewController.textView.textColor = ColorManager.shared.colorForKey("reply.text")
        replyViewController.sheetBackgroundColor = ColorManager.shared.colorForKey("reply.background")

        replyTopicFloor = floor
        if let floor = floor { // Reply Floor
            replyViewController.title = "@\(floor.author.name)"
        } else { // Reply Topic
            replyViewController.title = NSLocalizedString("ContentView_Reply_Title", comment: "Reply")
        }

        if let replyDraft = attributedReplyDraft {
            replyViewController.textView.attributedText = replyDraft
        }

        let frame = CGRect(x: 0.0, y: 0.0, width: replyViewController.view.bounds.width, height: 35.0)
        replyViewController.accessoryView = ReplyAccessoryView(frame: frame, withComposeViewController: replyViewController)
        replyViewController.textView.s1_resetToReplyStyle()

        present(replyViewController, animated: true, completion: nil)
    }
}

// MARK: Helper
private extension S1ContentViewController {

    func _hook_preChangeCurrentPage() {
        DDLogDebug("[webView] pre change current page")

        viewModel.cancelRequest()

        webPageReadyForAutomaticScrolling.value = false
        webPageDidFinishFirstAutomaticScrolling = false
        webPageAutomaticScrollingEnabled = true
    }

    func _hook_didFinishBasicPageLoad(for webView: WKWebView) {
        func changeOffsetIfNeeded(to offset: CGFloat) {
            if abs(webView.scrollView.contentOffset.y - offset) > 0.01 {
                webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: offset), animated: false)
                webView.scrollView.flashScrollIndicators()
            }
        }

        DDLogDebug("[webView] basic page loaded with scrollType \(scrollType) firstAnimationSkipped: \(webPageDidFinishFirstAutomaticScrolling)")
        let maxOffset = max(0.0, webView.scrollView.contentSize.height - webView.scrollView.bounds.height)

        switch scrollType {
        case .pullUpForNext:
            if webPageDidFinishFirstAutomaticScrolling {
                changeOffsetIfNeeded(to: 0.0)
                return
            }

            // Set position
            webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: -webView.bounds.height), animated: false)
            // Animated scroll
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseOut, animations: {
                webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
                webView.scrollView.s1_ignoringContentOffsetChange = true
                webView.scrollView.alpha = 1.0
            }, completion: { (_) in
                webView.scrollView.s1_ignoringContentOffsetChange = false
            })
        case .pullDownForPrevious:
            if webPageDidFinishFirstAutomaticScrolling {
                changeOffsetIfNeeded(to: maxOffset)
                return
            }

            // Set position
            webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: webView.scrollView.contentSize.height), animated: false)
            // Animated scroll
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseOut, animations: {
                webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: maxOffset), animated: false)
                webView.scrollView.s1_ignoringContentOffsetChange = true
                webView.scrollView.alpha = 1.0
            }, completion: { (_) in
                webView.scrollView.s1_ignoringContentOffsetChange = false
            })
        case .toBottom:
            if webPageDidFinishFirstAutomaticScrolling {
                changeOffsetIfNeeded(to: maxOffset)
                return
            }

            webView.evaluateJavaScript("$('html, body').animate({ scrollTop: $(document).height()}, 300);", completionHandler: nil)
        case .restorePosition:
            // Restore last view position from cached position in this view controller.
            if let positionForPage = viewModel.cachedOffsetForCurrentPage()?.s1_limit(0.0, to: maxOffset) {
                DDLogInfo("Trying to restore position of \(positionForPage)")

                changeOffsetIfNeeded(to: positionForPage)
            }
        }

        webPageDidFinishFirstAutomaticScrolling = true
        // FIXME: scroll type should turn back to restore position when other event occured.
    }

    // MARK: Helper (Misc)
    func updateToolBar() {
        forwardButton.setImage(viewModel.forwardButtonImage(), for: .normal)
        backButton.setImage(viewModel.backwardButtonImage(), for: .normal)
    }

    func _updateDecorationLines(contentSize: CGSize) {
        topDecorateLine.isHidden = viewModel.isInFirstPage() || !finishFirstLoading.value
        bottomDecorateLine.isHidden = !self.finishFirstLoading.value
    }

    func _tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated() {
        guard let title = webView.title, title != "" else {
            refreshCurrentPage(forceUpdate: !finishFirstLoading.value && viewModel.isInLastPage(), scrollType: .restorePosition)
            return
        }
    }

    func saveViewPositionForCurrentPage() {
        let currentOffsetY = webView.scrollView.contentOffset.y

        viewModel.cacheOffsetForCurrentPage(currentOffsetY)
    }

    func saveViewPositionForPreviousPage() {
        let currentOffsetY = webView.scrollView.contentOffset.y

        viewModel.cacheOffsetForPreviousPage(currentOffsetY)
    }

    func shouldPresentingFavoriteButtonOnToolBar() -> Bool {
        return view.bounds.width > 320.0 + 1.0
    }

    func hideHUD() {
            refreshHUD.hide(withDelay: 0.3)
    }

    func refreshCurrentPage(forceUpdate: Bool, scrollType: ScrollType) {
        viewModel.cancelRequest() // ???: Maybe remove this?
        self.scrollType = scrollType
        _hook_preChangeCurrentPage()
        viewModel.currentPage.value = viewModel.currentPage.value
        fetchContentForCurrentPage(forceUpdate: forceUpdate)
    }
}

// MARK: - State
extension S1ContentViewController {
    enum ScrollType: String {
        case restorePosition
        case pullUpForNext
        case pullDownForPrevious
        case toBottom
    }

    enum BackButtonState {
        case back(rotateAngle: Double)
    }

    enum ForwardButtonState {
        case forward(rotateAngle: Double)
        case refresh(rotateAngle: Double)
    }
}

enum PresentType {
    case none
    case image // Note: partly tracked in protocol extension
    case content
    case user // Note: tracked in protocol extension
    case quote
    case report
    case background

    // Note: not tracked for now
    case web // Note: WebViewController do not hide view controller under it
    case actionSheet // Note: UIAlertController do not hide view controller under it
    case alert // Note: UIAlertController do not hide view controller under it
    case reply // Note: REComposeViewController do not hide view controller under it
}
