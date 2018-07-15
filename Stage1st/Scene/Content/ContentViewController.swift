//
//  ContentViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/10/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import WebKit
import SnapKit
import Ainoaibo
import ActionSheetPicker_3_0
import JTSImageViewController
import Crashlytics
import ReactiveSwift
import ReactiveCocoa
import Photos

private let topOffset: CGFloat = -80.0
private let bottomOffset: CGFloat = 60.0
private let blankPageHTMLString = """
    <!DOCTYPE html>
    <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html;">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      </head>
      <body style="height: 1px; width: 1px">
      </body>
    </html>
    """

class S1ContentViewController: UIViewController, ImagePresenter, UserPresenter, ContentPresenter, QuoteFloorPresenter {
    let viewModel: ContentViewModel

    lazy var webView: WKWebView = {
        WKWebView(frame: .zero, configuration: self.sharedWKWebViewConfiguration())
    }()
    lazy var pullToActionController: PullToActionController = {
        PullToActionController(scrollView: self.webView.scrollView)
    }()

    let refreshHUD = S1HUD(frame: .zero)
    let hintHUD = S1HUD(frame: .zero)

    let toolBar = UIToolbar(frame: .zero)
    let backButton = UIButton(type: .system)
    let forwardButton = UIButton(type: .system)
    let pageButton = UIButton(frame: .zero)
    let favoriteButton = UIButton(type: .system)
    lazy var actionBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(action(sender:)))
    }()

    var basicToolBarItems = [UIBarButtonItem]()
    var optionalToolBarItems = [UIBarButtonItem]()

    let titleLabel = UILabel(frame: .zero)
    let topDecorateLine = UIView(frame: .zero)
    let bottomDecorateLine = UIView(frame: .zero)

    var scrollType: ScrollType = .restorePosition {
        didSet { S1LogInfo("[ContentVC] scroll type changed: \(oldValue.rawValue) -> \(scrollType.rawValue)") }
    }

    var backButtonState: BackButtonState = .back(rotateAngle: 0.0) {
        didSet { updateBackButtonAppearance(oldValue) }
    }

    var forwardButtonState: ForwardButtonState = .forward(rotateAngle: 0.0) {
        didSet { updateForwardButtonAppearance(oldValue) }
    }

    /// No automatic scrolling should happen before first loading.
    let finishFirstLoading = MutableProperty(false)
    /// No automatic scrolling should happen before content ready. ready signal will trigger first automatic scrolling.
    let webPageReadyForAutomaticScrolling = MutableProperty(false)
    /// Every content height change will trying to trigger automatic scrolling.
    let webPageCurrentContentHeight = MutableProperty(0.0 as CGFloat)

    /// Note: User interaction will disable automatic scrolling.
    var webPageAutomaticScrollingEnabled = true
    /// Note: Only first automatic scrolling has animation.
    var webPageDidFinishFirstAutomaticScrolling = false

    var presentType: PresentType = .none {
        didSet { logCurrentPresentingViewController() }
    }

    var replyDraft: NSAttributedString?

    // MARK: -
    @objc convenience init(topic: S1Topic, dataCenter: DataCenter) {
        self.init(viewModel: ContentViewModel(topic: topic, dataCenter: dataCenter))
    }

    @objc init(viewModel: ContentViewModel) {
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

        self.basicToolBarItems = [
            backwardItem,
            fixItem,
            forwardItem,
            flexItem,
            labelItem,
            flexItem
        ]

        self.optionalToolBarItems = [
            favoriteItem,
            fixItem2
        ]

        if shouldPresentingFavoriteButtonOnToolBar() {
            toolBar.setItems(basicToolBarItems + optionalToolBarItems + [actionBarButtonItem], animated: false)
        } else {
            toolBar.setItems(basicToolBarItems + [actionBarButtonItem], animated: false)
        }

        // Binding
        viewModel.currentPage.producer
            .combineLatest(with: viewModel.totalPages.producer)
            .startWithValues { [weak self] arg in
                let (currentPage, totalPage) = arg

                S1LogVerbose("[ContentVM] Current page or totoal page changed: \(currentPage)/\(totalPage)")
                guard let strongSelf = self else { return }
                strongSelf.pageButton.setTitle(strongSelf.viewModel.pageButtonString(), for: .normal)
            }

        SignalProducer
            .combineLatest(webPageReadyForAutomaticScrolling.producer, webPageCurrentContentHeight.producer)
            .startWithValues { [weak self] arg in
                let (webPageReady, currentHeight) = arg

                guard let strongSelf = self else { return }
                let finishFirstLoading = strongSelf.finishFirstLoading.value
                S1LogVerbose("[ContentVC] document ready: \(webPageReady), finish first loading: \(finishFirstLoading), current height: \(currentHeight), scrolling enable: \(strongSelf.webPageAutomaticScrollingEnabled)")

                if webPageReady && finishFirstLoading && strongSelf.webPageAutomaticScrollingEnabled {
                    strongSelf.pullToActionController.filterDuplicatedSizeEvent = true
                    DispatchQueue.main.async { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf._hook_didFinishBasicPageLoad(for: strongSelf.webView)
                    }
                }
            }

        favoriteButton.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.viewModel.toggleFavorite()
        }

        viewModel.favorite.producer
            .take(during: reactive.lifetime)
            .map { $0?.boolValue ?? false }
            .startWithValues { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.favoriteButton.setImage(strongSelf.viewModel.favoriteButtonImage(), for: .normal)
            }

        viewModel.title.producer
            .take(during: reactive.lifetime)
            .startWithValues { [weak self] title in
                guard let strongSelf = self else { return }
                if let title = title, title != "" {
                    strongSelf.titleLabel.text = title as String
                    strongSelf.titleLabel.textColor = AppEnvironment.current.colorManager.colorForKey("content.titlelabel.text.normal")
                } else {
                    strongSelf.titleLabel.text = "\(strongSelf.viewModel.topic.topicID) 载入中..."
                    strongSelf.titleLabel.textColor = AppEnvironment.current.colorManager.colorForKey("content.titlelabel.text.disable")
                }
            }

        // Activity
        _setupActivity()

        // Notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: .UIApplicationWillEnterForeground,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: .UIApplicationDidEnterBackground,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceivePaletteChangeNotification(_:)),
            name: .APPaletteDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveFloorCachedNotification(_:)),
            name: .S1FloorsDidCachedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveUserBlockStatusDidChangedNotification(_:)),
            name: .UserBlockStatusDidChangedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveReplyDidPostedNotification(_:)),
            name: .ReplyDidPosted,
            object: nil
        )
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        S1LogInfo("[ContentVC] Dealloc Begin")
        NotificationCenter.default.removeObserver(self)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "stage1st")
        pullToActionController.stop()
        webView.stopLoading()
        S1LogInfo("[ContentVC] Dealloced")
    }
}

// MARK: - Life Cycle
extension S1ContentViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(toolBar)
        toolBar.snp.makeConstraints { make in
            make.leading.trailing.equalTo(self.view)
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
        }

        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(self.view)
            make.top.equalTo(self.topLayoutGuide.snp.bottom)
            make.bottom.equalTo(self.toolBar.snp.top)
        }

        view.layoutIfNeeded()

        webView.scrollView.addSubview(topDecorateLine)
        topDecorateLine.snp.makeConstraints { make in
            make.leading.trailing.equalTo(self.webView)
            make.height.equalTo(1.0)
            make.bottom.equalTo(self.webView.scrollView.subviews[0].snp.top).offset(topOffset)
        }

        webView.scrollView.addSubview(bottomDecorateLine)
        bottomDecorateLine.snp.makeConstraints { make in
            make.leading.trailing.equalTo(self.webView)
            make.height.equalTo(1.0)
            make.top.equalTo(self.webView.scrollView.subviews[0].snp.bottom).offset(bottomOffset)
        }

        webView.scrollView.insertSubview(titleLabel, at: 0)
        titleLabel.snp.makeConstraints { make in
            let contentView = self.webView.scrollView.subviews[1]
            assert(
                contentView.isKind(of: NSClassFromString("WKContentView")!),
                "titleLabel can not layout correctly if WKContentView missing."
            )
            make.bottom.equalTo(contentView.snp.top)
            make.centerX.equalTo(contentView.snp.centerX)
            make.width.equalTo(self.webView.scrollView.snp.width).offset(-24.0)
        }

        view.addSubview(refreshHUD)
        refreshHUD.snp.makeConstraints { make in
            make.center.equalTo(self.view)
            make.width.lessThanOrEqualTo(self.view).priority(250.0)
        }

        view.addSubview(hintHUD)
        hintHUD.snp.makeConstraints { make in
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
        S1LogDebug("[ContentVC] View did disappear end")
    }

    @objc func applicationWillEnterForeground() {
        S1LogDebug("[ContentVC] \(self) will enter foreground begin")
        _tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated()
    }

    @objc func applicationDidEnterBackground() {
        S1LogDebug("[ContentVC] \(self) did enter background begin")
        saveTopicViewedState(sender: nil)
        S1LogDebug("[ContentVC] \(self) did enter background end")
    }
}

// MARK: - Actions
extension S1ContentViewController {
    @objc open func back(sender: Any?) {
        if viewModel.isInFirstPage() {
            _ = navigationController?.popViewController(animated: true)
        } else {
            if sender as? WKWebView != nil {
                scrollType = .pullDownForPrevious
            } else {
                scrollType = .restorePosition
            }
            _hook_preChangeCurrentPage()
            viewModel.currentPage.value -= 1
            fetchContentForCurrentPage(forceUpdate: false)
        }
    }

    @objc open func forward(sender: Any?) {
        switch (viewModel.isInLastPage(), webView.s1_atBottom()) {
        case (true, false):
            webView.s1_scrollToBottom(animated: true)
        case (true, true):
            refreshCurrentPage(forceUpdate: true, scrollType: .restorePosition)
        case (false, _):
            if sender is WKWebView {
                scrollType = .pullUpForNext
            } else {
                scrollType = .restorePosition
            }
            _hook_preChangeCurrentPage()
            viewModel.currentPage.value += 1
            fetchContentForCurrentPage(forceUpdate: false)
        }
    }

    @objc open func backLongPressed(gestureRecognizer: UIGestureRecognizer) {
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

    @objc open func forwardLongPressed(gestureRecognizer: UIGestureRecognizer) {
        guard
            gestureRecognizer.state == UIGestureRecognizerState.began,
            !viewModel.isInLastPage() else {
            return
        }

        scrollType = .restorePosition
        _hook_preChangeCurrentPage()
        viewModel.currentPage.value = max(viewModel.totalPages.value, 1)
        fetchContentForCurrentPage(forceUpdate: false)
    }

    @objc open func pickPage(sender _: Any?) {
        func generatePageList() -> [String] {
            var pageList = [String]()

            for page in 1 ... max(viewModel.currentPage.value, viewModel.totalPages.value) {
                if viewModel.dataCenter.hasPrecachedFloors(for: Int(truncating: viewModel.topic.topicID), page: page) {
                    pageList.append("✓第 \(page) 页✓")
                } else {
                    pageList.append("第 \(page) 页")
                }
            }

            return pageList
        }

        let pageList = generatePageList()

        let picker = ActionSheetStringPicker(title: "", rows: pageList, initialSelection: Int(viewModel.currentPage.value - 1), doneBlock: { [weak self] _, selectedIndex, _ in
            guard let strongSelf = self else { return }

            if strongSelf.viewModel.currentPage.value == UInt(selectedIndex + 1) {
                strongSelf.refreshCurrentPage(forceUpdate: true, scrollType: .restorePosition)
            } else {
                strongSelf.scrollType = .restorePosition
                strongSelf._hook_preChangeCurrentPage()
                strongSelf.viewModel.currentPage.value = selectedIndex + 1
                strongSelf.fetchContentForCurrentPage(forceUpdate: false)
            }
        }, cancel: nil, origin: pageButton)

        picker?.pickerBackgroundColor = AppEnvironment.current.colorManager.colorForKey("content.picker.background")
        picker?.toolbarBackgroundColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.bartint")
        picker?.toolbarButtonsColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.tint")

        let labelParagraphStyle = NSMutableParagraphStyle()
        labelParagraphStyle.alignment = .center
        picker?.pickerTextAttributes = [
            NSAttributedStringKey.paragraphStyle: labelParagraphStyle,
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 19.0),
            NSAttributedStringKey.foregroundColor: AppEnvironment.current.colorManager.colorForKey("content.picker.text"),
        ]
        picker?.show()
    }

    @objc open func forceRefreshPressed(gestureRecognizer: UIGestureRecognizer) {
        guard gestureRecognizer.state == .began else {
            return
        }

        S1LogDebug("[ContentVC] Force refresh pressed")
        refreshCurrentPage(forceUpdate: true, scrollType: .restorePosition)
    }

    @objc open func action(sender _: Any?) {
        let moreActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Reply Action
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.ActionSheet.Reply", comment: "Reply"), style: .default, handler: { [weak self] _ in
            guard let strongSelf = self else { return }

            guard AppEnvironment.current.settings.currentUsername.value != nil else {
                Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                    "type": "ReplyTopic",
                    "source": "Content",
                    "result": "Failed",
                ])

                let loginViewController = LoginViewController(nibName: nil, bundle: nil)
                strongSelf.present(loginViewController, animated: true, completion: nil)
                return
            }

            guard strongSelf.viewModel.topic.fID != nil, strongSelf.viewModel.topic.formhash != nil else {
                Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                    "type": "ReplyTopic",
                    "source": "Content",
                    "result": "Failed",
                ])
                strongSelf._alertRefresh()
                return
            }

            Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                "type": "ReplyTopic",
                "source": "Content",
                "result": "Succeeded",
            ])

            strongSelf._presentReplyView(toFloor: nil)
        }))

        if !shouldPresentingFavoriteButtonOnToolBar() {
            // Favorite Action
            let title = viewModel.topic.favorite?.boolValue ?? false ? NSLocalizedString("ContentViewController.ActionSheet.CancelFavorite", comment: "Cancel Favorite") : NSLocalizedString("ContentViewController.ActionSheet.Favorite", comment: "Favorite")
            moreActionSheet.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.viewModel.toggleFavorite()
                let message = strongSelf.viewModel.topic.favorite?.boolValue ?? false ? NSLocalizedString("ContentViewController.ActionSheet.Favorite", comment: "Favorite") : NSLocalizedString("ContentViewController.ActionSheet.CancelFavorite", comment: "Cancel Favorite")
                strongSelf.hintHUD.showMessage(message)
                strongSelf.hintHUD.hide(withDelay: 0.5)
            }))
        }

        // Share Action
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.ActionSheet.Share", comment: "Share"), style: .default, handler: { [weak self] _ in
            guard let strongSelf = self else { return }

            let rect = mutate(strongSelf.view.bounds) { (value: inout CGRect) in
                value.origin.y += 20.0
                value.size.height -= 20.0
            }

            let items: [Any] = [
                ContentTextActivityItemProvider(
                    title: strongSelf.viewModel.topic.title ?? "",
                    urlString: strongSelf.viewModel.correspondingWebPageURL()?.absoluteString ?? ""
                ),
                ContentImageActivityItemProvider(
                    view: strongSelf.view,
                    cropTo: rect
                )
            ]

            let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
            activityController.popoverPresentationController?.barButtonItem = strongSelf.actionBarButtonItem

            Answers.logCustomEvent(withName: "Share", customAttributes: [
                "object": "Topic",
                "source": "Content",
                ])
            strongSelf.present(activityController, animated: true, completion: nil)
        }))

        // Copy Link
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.ActionSheet.CopyLink", comment: "Copy Link"), style: .default, handler: { [weak self] _ in
            guard let strongSelf = self else { return }
            if let urlString = strongSelf.viewModel.correspondingWebPageURL()?.absoluteString {
                UIPasteboard.general.string = urlString
                strongSelf.hintHUD.showMessage(NSLocalizedString("ContentViewController.ActionSheet.CopyLink", comment: "Copy Link"))
                strongSelf.hintHUD.hide(withDelay: 0.3)
            } else {
                S1LogWarn("[ContentVC] can not generate corresponding web page url.")
            }
        }))

        // Origin Page Action
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.ActionSheet.OriginPage", comment: "Origin"), style: .default, handler: { [weak self] _ in
            guard let strongSelf = self else { return }
            if let urlToOpen = strongSelf.viewModel.correspondingWebPageURL() {
                let webViewController = WebViewController(URL: urlToOpen)
                strongSelf.present(webViewController, animated: true, completion: nil)
            } else {
                S1LogWarn("[ContentVC] can not generate corresponding web page url.")
            }
        }))

        // Cancel Action
        moreActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.ActionSheet.Cancel", comment: "Cancel"), style: .cancel, handler: nil))

        moreActionSheet.popoverPresentationController?.barButtonItem = actionBarButtonItem
        present(moreActionSheet, animated: true, completion: nil)
    }

    open func actionButtonTapped(for floorID: Int) {
        guard let floor = viewModel.searchFloorInCache(floorID) else {
            return
        }

        let settings = AppEnvironment.current.settings

        let replyFloorBlock = { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.viewModel.topic.formhash != nil && strongSelf.viewModel.topic.fID != nil else {
                Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                    "type": "ReplyFloor",
                    "source": "Content",
                    "result": "Failed",
                ])
                strongSelf._alertRefresh()
                return
            }

            guard settings.currentUsername.value != nil else {
                Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                    "type": "ReplyFloor",
                    "source": "Content",
                    "result": "Failed",
                ])
                let loginViewController = LoginViewController(nibName: nil, bundle: nil)
                strongSelf.present(loginViewController, animated: true, completion: nil)
                return
            }

            Answers.logCustomEvent(withName: "Click Reply", customAttributes: [
                "type": "ReplyFloor",
                "source": "Content",
                "result": "Succeeded",
            ])
            strongSelf._presentReplyView(toFloor: floor)
        }

        if settings.reverseAction.value {
            replyFloorBlock()
            return
        }

        S1LogDebug("[ContentVC] Action for \(floor)")
        let floorActionController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.FloorActionSheet.Report", comment: ""), style: .destructive, handler: { [weak self] _ in
            guard let strongSelf = self else { return }
            guard strongSelf.viewModel.topic.formhash != nil && strongSelf.viewModel.topic.fID != nil else {
                Answers.logCustomEvent(withName: "Click Report", customAttributes: [
                    "source": "Content",
                    "result": "Failed",
                ])
                strongSelf._alertRefresh()
                return
            }

            guard AppEnvironment.current.settings.currentUsername.value != nil else {
                Answers.logCustomEvent(withName: "Click Report", customAttributes: [
                    "source": "Content",
                    "result": "Failed",
                ])
                let loginViewController = LoginViewController(nibName: nil, bundle: nil)
                strongSelf.present(loginViewController, animated: true, completion: nil)
                return
            }

            Answers.logCustomEvent(withName: "Click Report", customAttributes: [
                "source": "Content",
                "result": "Succeeded",
            ])
            strongSelf.presentType = .report
            let reportViewModel = strongSelf.viewModel.reportComposeViewModel(floor: floor)
            let reportComposeViewController = ReportComposeViewController(viewModel: reportViewModel)
            strongSelf.present(UINavigationController(rootViewController: reportComposeViewController), animated: true, completion: nil)
        }))

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.FloorActionSheet.Reply", comment: ""), style: .default, handler: { _ in
            replyFloorBlock()
        }))

        floorActionController.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.FloorActionSheet.Cancel", comment: ""), style: .cancel, handler: nil))

        if let popover = floorActionController.popoverPresentationController {
            popover.delegate = self
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                popover.sourceView = strongSelf.webView
                strongSelf.webView.s1_positionOfElement(with: "\(floorID)-action") { [weak self] (rect) in
                    guard let strongSelf = self else { return }
                    popover.sourceRect = rect ?? CGRect(origin: strongSelf.webView.center, size: .zero)
                    strongSelf.present(floorActionController, animated: true, completion: nil)
                }
            }
        } else {
            present(floorActionController, animated: true, completion: nil)
        }
    }

    func _alertRefresh() {
        let refreshAlertController = UIAlertController(
            title: "缺少必要的信息",
            message: "请长按页码刷新当前页面",
            preferredStyle: .alert
        )

        refreshAlertController.addAction(UIAlertAction(
            title: "好",
            style: .cancel,
            handler: nil
        ))

        present(refreshAlertController, animated: true, completion: nil)
    }

    open func saveTopicViewedState(sender _: Any?) {
        if finishFirstLoading.value {
            viewModel.saveTopicViewedState(lastViewedPosition: Double(webView.scrollView.contentOffset.y))
        } else {
            viewModel.saveTopicViewedState(lastViewedPosition: nil)
        }
    }

    open override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        // Color
        view.backgroundColor = AppEnvironment.current.colorManager.colorForKey("content.background")
        webView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("content.webview.background")
        webView.scrollView.indicatorStyle = AppEnvironment.current.colorManager.isDarkTheme() ? .white : .default
        topDecorateLine.backgroundColor = AppEnvironment.current.colorManager.colorForKey("content.decoration.line")
        bottomDecorateLine.backgroundColor = AppEnvironment.current.colorManager.colorForKey("content.decoration.line")
        if let title = self.viewModel.topic.title, title != "" {
            titleLabel.textColor = AppEnvironment.current.colorManager.colorForKey("content.titlelabel.text.normal")
        } else {
            titleLabel.textColor = AppEnvironment.current.colorManager.colorForKey("content.titlelabel.text.disable")
        }
        pageButton.setTitleColor(AppEnvironment.current.colorManager.colorForKey("content.pagebutton.text"), for: .normal)
        toolBar.barTintColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.bartint")
        toolBar.tintColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.tint")

        setNeedsStatusBarAppearanceUpdate()

        if notification != nil {
            saveViewPositionForCurrentPage()
            refreshCurrentPage(forceUpdate: false, scrollType: .restorePosition)
        }
    }

    @objc open func didReceiveFloorCachedNotification(_ notification: Notification?) {
        guard
            let topicID = notification?.userInfo?["topicID"] as? NSNumber,
            let page = notification?.userInfo?["page"] as? NSNumber,
            viewModel.topic.topicID.intValue == topicID.intValue,
            page.intValue - Int(viewModel.currentPage.value) == 1 else {
            return
        }

        updateToolBar()
    }

    @objc open func didReceiveUserBlockStatusDidChangedNotification(_: Notification?) {
        refreshCurrentPage(forceUpdate: false, scrollType: .restorePosition)
    }

    @objc open func didReceiveReplyDidPostedNotification(_ notification: Notification) {
        guard
            let topicID = notification.userInfo?["topicID"] as? NSNumber,
            viewModel.topic.topicID.isEqual(to: topicID)
        else {
            return
        }

        self.replyDraft = nil

        if viewModel.isInLastPage() {
            refreshCurrentPage(forceUpdate: true, scrollType: .toBottom)
        }
    }
}

// MARK: -
// MARK: WKNavigationDelegate
extension S1ContentViewController: WKNavigationDelegate {
    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        S1LogInfo("[ContentVC] webViewDidFinishLoad")
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        S1LogWarn("[ContentVC] webview failed to load with error: \(error)")
    }

    func webViewWebContentProcessDidTerminate(_: WKWebView) {
        S1LogError("[ContentVC] webViewWebContentProcessDidTerminate")
    }

    func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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
                "source": "Content",
            ])
            showImageViewController(transitionSource: .offScreen, imageURL: url)
            decisionHandler(.cancel)
            return
        }

        if AppEnvironment.current.serverAddress.hasSameDomain(with: url) {
            // Open as S1 topic
            if let topic = S1Parser.extractTopicInfo(fromLink: url.absoluteString) {
                // TODO: Make this logic easy to understand.
                var topic = topic
                if let tracedTopic = viewModel.dataCenter.traced(topicID: topic.topicID.intValue) {
                    let lastViewedPage = topic.lastViewedPage
                    topic = tracedTopic.copy() as! S1Topic
                    if lastViewedPage != nil {
                        topic.lastViewedPage = lastViewedPage
                    }
                }

                Answers.logCustomEvent(withName: "Open Topic Link", customAttributes: [
                    "source": "Content",
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
                    "source": "Content",
                ])
                showQuoteFloorViewController(floors: chainQuoteFloors, centerFloorID: chainQuoteFloors.last!.ID)
                decisionHandler(.cancel)
                return
            }
        }

        // Fallback Open link
        let alertViewController = UIAlertController(title: NSLocalizedString("ContentViewController.WebView.OpenLinkAlert.Title", comment: ""), message: url.absoluteString, preferredStyle: .alert)
        alertViewController.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.WebView.OpenLinkAlert.Cancel", comment: ""), style: .cancel, handler: nil))
        alertViewController.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.WebView.OpenLinkAlert.Open", comment: ""), style: .default, handler: { _ in
            S1LogInfo("[ContentVC] Open in Safari: \(url)")

            UIApplication.shared.open(url, options: [:], completionHandler: { (success) in
                if !success {
                    S1LogWarn("Failed to open url: \(url)")
                }
            })
        }))

        present(alertViewController, animated: true, completion: nil)

        S1LogWarn("No case match for url: \(url), fallback to asking for open link.")
        decisionHandler(.cancel)
        return
    }
}

// MARK: - WebViewEventDelegate
extension S1ContentViewController: WebViewEventDelegate {
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, readyWith _: [String: Any]) {
        webPageReadyForAutomaticScrolling.value = true
    }

    func generalScriptMessageHandlerTouchEvent(_: GeneralScriptMessageHandler) {
        let currentColorPanGestureState = (UIApplication.shared.delegate as! S1AppDelegate).rootNavigationController?.gagat?.panGestureRecognizer.state ?? .possible
        let shouldIgnoreTouchEvent = currentColorPanGestureState == .began || currentColorPanGestureState == .changed
        if webPageDidFinishFirstAutomaticScrolling && webPageAutomaticScrollingEnabled && !shouldIgnoreTouchEvent {
            S1LogInfo("[ContentVC] User Touch detected. Stop tracking scroll type: \(scrollType)")
            webPageAutomaticScrollingEnabled = false
            webView.scrollView.s1_ignoringContentOffsetChangedToZero = false
        }
    }

    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, actionButtonTappedFor floorID: Int) {
        actionButtonTapped(for: floorID)
    }
}

extension S1ContentViewController {
    func sharedWKWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(GeneralScriptMessageHandler(delegate: self), name: "stage1st")
        configuration.userContentController = userContentController
        if #available(iOS 11.0, *) {
            configuration.setURLSchemeHandler(AppEnvironment.current.webKitImageDownloader, forURLScheme: "image")
            configuration.setURLSchemeHandler(AppEnvironment.current.webKitImageDownloader, forURLScheme: "images")
        }
        return configuration
    }
}

// MARK: - JTSImageViewControllerInteractionsDelegate
extension S1ContentViewController: JTSImageViewControllerInteractionsDelegate {
    func imageViewerDidLongPress(_ imageViewer: JTSImageViewController!, at rect: CGRect) {
        let imageActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        imageActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ImageViewController.ActionSheet.Save", comment: "Save"), style: .default, handler: { _ in
            DispatchQueue.global(qos: .background).async {
                PHPhotoLibrary.requestAuthorization { status in
                    guard case .authorized = status else {
                        S1LogError("No auth to access photo library")
                        return
                    }

                    let imageData = imageViewer.imageData
                    guard imageData != nil else {
                        S1LogError("Image data is nil")
                        return
                    }

                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData!, options: nil)
                    }, completionHandler: { _, error in
                        if let error = error {
                            S1LogError("\(error)")
                        }
                    })
                }
            }
        }))

        imageActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ImageViewController.ActionSheet.CopyURL", comment: "Copy URL"), style: .default, handler: { _ in
            UIPasteboard.general.string = imageViewer.imageInfo.imageURL.absoluteString
        }))

        imageActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ContentViewController.ActionSheet.Cancel", comment: "Cancel"), style: .cancel, handler: nil))

        imageActionSheet.popoverPresentationController?.sourceView = imageViewer.view
        imageActionSheet.popoverPresentationController?.sourceRect = rect
        imageViewer.present(imageActionSheet, animated: true, completion: nil)
    }
}

// MARK: JTSImageViewControllerOptionsDelegate
extension S1ContentViewController: JTSImageViewControllerOptionsDelegate {
    func alphaForBackgroundDimmingOverlay(inImageViewer _: JTSImageViewController!) -> CGFloat {
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
            finishFirstLoading.value,
            !viewModel.isInFirstPage() else {
            return
        }

        var currentContentOffset = webView.scrollView.contentOffset
        //        currentContentOffset.y = -self.webView.bounds.height
        currentContentOffset.y -= webView.bounds.height / 2

        // DIRTYHACK: delay 0.01 second to avoid animation to overrided by other animation setted by iOS
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.webView.scrollView.setContentOffset(currentContentOffset, animated: false)
                strongSelf.webView.scrollView.alpha = 0.0
            }, completion: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.back(sender: strongSelf.webView)
            })
        }
    }

    public func scrollViewDidEndDraggingOutsideBottomBound(with offset: CGFloat) {
        guard
            offset > bottomOffset,
            finishFirstLoading.value else {
            return
        }

        guard !viewModel.isInLastPage() else {
            // Only refresh triggered in last page
            forward(sender: nil)
            return
        }

        var currentContentOffset = webView.scrollView.contentOffset
        //        currentContentOffset.y = self.webView.scrollView.contentSize.height
        currentContentOffset.y += webView.bounds.height / 2

        // DIRTYHACK: delay 0.01 second to avoid animation to overrided by other animation setted by iOS
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.webView.scrollView.setContentOffset(currentContentOffset, animated: false)
                strongSelf.webView.scrollView.alpha = 0.0
            }, completion: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.forward(sender: strongSelf.webView)
            })
        }
    }

    public func scrollViewContentSizeDidChange(_ contentSize: CGSize) {
        _updateDecorationLines(contentSize: contentSize)
        webPageCurrentContentHeight.value = CGFloat(contentSize.height)
    }

    public func scrollViewContentOffsetProgress(_ progress: [String: Double]) {
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
                forwardButtonState = .forward(rotateAngle: bottomProgress.aibo_clamped(to: 0.0...1.0))
            }
        }

        // Process for top offset
        if let topProgress = progress["top"] {
            if viewModel.isInFirstPage() {
                backButtonState = .back(rotateAngle: 0.0)
            } else {
                backButtonState = .back(rotateAngle: topProgress.aibo_clamped(to: 0.0...1.0))
            }
        }
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension S1ContentViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationController(_: UIPopoverPresentationController, willRepositionPopoverTo _: UnsafeMutablePointer<CGRect>, in _: AutoreleasingUnsafeMutablePointer<UIView>) {
        // TODO: find a solution.
        //        guard case .action(let floorID) = presentType else { return }
        //        DispatchQueue.global(qos: .default).async { [weak self] in
        //            guard let strongSelf = self else { return }
        //            rect.pointee = strongSelf.webView.s1_positionOfElement(with: "\(floorID)-action")
        //        }
    }
}

// MARK: - ReplyViewControllerDraftDelegate
extension S1ContentViewController: ReplyViewControllerDraftDelegate {
    func replyViewController(_ replyViewController: ReplyViewController, didCancelledWith draft: NSAttributedString) {
        self.replyDraft = draft
    }

    func replyViewControllerDidFailed(with draft: NSAttributedString) {
        self.replyDraft = draft
    }
}

// MARK: - Layout & Style
extension S1ContentViewController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        S1LogDebug("viewWillTransitionToSize: \(size)")

        var frame = view.frame
        frame.size = size
        view.frame = frame

        // Update Toolbar Layout
        if shouldPresentingFavoriteButtonOnToolBar() {
            toolBar.setItems(basicToolBarItems + optionalToolBarItems + [actionBarButtonItem], animated: false)
        } else {
            toolBar.setItems(basicToolBarItems + [actionBarButtonItem], animated: false)
        }
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
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
        S1LogDebug("[ContentVC] Hand Off Activity Updated")
        activity.userInfo = viewModel.activityUserInfo()
        activity.webpageURL = viewModel.correspondingWebPageURL() as URL?
    }
}

// MARK: - Main Function
extension S1ContentViewController {
    func fetchContentForCurrentPage(forceUpdate: Bool) {
        func _showHud() {
            refreshHUD.showActivityIndicator()

            refreshHUD.refreshEventHandler = { [weak self] hud in
                guard let strongSelf = self else { return }

                hud?.hide(withDelay: 0.0)
                strongSelf.refreshCurrentPage(forceUpdate: true, scrollType: strongSelf.scrollType)
            }
        }

        updateToolBar()

        userActivity?.needsSave = true

        // remove cache for last page
        if forceUpdate {
            viewModel.dataCenter.removePrecachedFloors(for: viewModel.topic, with: Int(viewModel.currentPage.value))
        }

        // Set up HUD
        if !viewModel.hasValidPrecachedCurrentPage() {
            // only show hud when no cached floors
            S1LogVerbose("[ContentVC] check precache: not hit. shows HUD")
            _showHud()
        } else {
            S1LogVerbose("[ContentVC] check precache: hit.")
        }

        viewModel.currentContentPage { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case let .success(contents):
                S1LogInfo("[ContentVC] page finish fetching.")
                strongSelf.updateToolBar() /// TODO: Is it still necessary?

                if strongSelf.finishFirstLoading.value {
                    strongSelf.saveViewPositionForPreviousPage()
                }
                strongSelf.finishFirstLoading.value = true
                strongSelf.webView.loadHTMLString(contents, baseURL: strongSelf.viewModel.pageBaseURL())

                // Prepare next page
                if (!strongSelf.viewModel.isInLastPage()) && AppEnvironment.current.settings.precacheNextPage.value {
                    strongSelf.viewModel.dataCenter.precacheFloors(for: strongSelf.viewModel.topic, with: Int(strongSelf.viewModel.currentPage.value) + 1, shouldUpdate: false)
                }

                // Dismiss HUD if exist
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.refreshHUD.hide(withDelay: 0.3)
                }

            case let .failure(error):
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    S1LogDebug("[ContentVC] request cancelled.")
                    // TODO:
                    //            if (strongSelf.refreshHUD != nil) {
                    //                [strongSelf.refreshHUD hideWithDelay:0.3];
                    //            }
                } else if case let DZError.serverError(message) = error {
                    S1LogInfo("[ContentVC] Permission denied with message: \(error)")
                    strongSelf.refreshHUD.showMessage(message)
                    strongSelf.refreshHUD.hide(withDelay: 3.0)
                } else {
                    S1LogWarn("[ContentVC] fetch failed with error: \(error)")
                    strongSelf.refreshHUD.showRefreshButton()
                }
            }
        }
    }

    func _presentReplyView(toFloor floor: Floor?) {
        func target(for floor: Floor?) -> ReplyViewModel.ReplyTarget {
            if let floor = floor {
                return .floor(floor, page: viewModel.currentPage.value)
            } else {
                return .topic
            }
        }

        let replyViewModel = ReplyViewModel(
            topic: viewModel.topic,
            target: target(for: floor)
        )

        let replyViewController = ReplyViewController(viewModel: replyViewModel)
        replyViewController.draftDelegate = self
        replyViewController.textView.attributedText = self.replyDraft ?? NSAttributedString()

        present(replyViewController, animated: true, completion: nil)
    }
}

// MARK: Helper
private extension S1ContentViewController {

    func _hook_preChangeCurrentPage() {
        S1LogDebug("[webView] pre change current page")

        viewModel.cancelRequest()

        webPageReadyForAutomaticScrolling.value = false
        webPageDidFinishFirstAutomaticScrolling = false
        webPageAutomaticScrollingEnabled = true
        pullToActionController.filterDuplicatedSizeEvent = false
    }

    func _hook_didFinishBasicPageLoad(for webView: WKWebView) {
        func changeOffsetIfNeeded(to offset: CGFloat) {
            if abs(webView.scrollView.contentOffset.y - offset) > 0.01 {
                let originalOption = webView.scrollView.s1_ignoringContentOffsetChangedToZero
                webView.scrollView.s1_ignoringContentOffsetChangedToZero = false
                webView.scrollView.setContentOffset(CGPoint(x: webView.scrollView.contentOffset.x, y: offset), animated: false)
                webView.scrollView.s1_ignoringContentOffsetChangedToZero = originalOption
                webView.scrollView.flashScrollIndicators()
            }
        }

        S1LogDebug("[webView] basic page loaded with scrollType \(scrollType) firstAnimationSkipped: \(webPageDidFinishFirstAutomaticScrolling)")
        let maxOffset = max(0.0, webView.scrollView.contentSize.height - webView.scrollView.bounds.height)

        switch scrollType {
        case .pullUpForNext:
            if webPageDidFinishFirstAutomaticScrolling {
                changeOffsetIfNeeded(to: 0.0)
                return
            }

            // Set position
            webView.scrollView.setContentOffset(CGPoint(x: webView.scrollView.contentOffset.x, y: -webView.bounds.height), animated: false)
            // Animated scroll
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseOut, animations: {
                webView.scrollView.setContentOffset(CGPoint(x: webView.scrollView.contentOffset.x, y: 0.0), animated: false)
                webView.scrollView.s1_ignoringContentOffsetChangedToZero = true
                webView.scrollView.alpha = 1.0
            }, completion: { _ in
                webView.scrollView.s1_ignoringContentOffsetChangedToZero = false
                webView.scrollView.flashScrollIndicators()
            })
        case .pullDownForPrevious:
            if webPageDidFinishFirstAutomaticScrolling {
                changeOffsetIfNeeded(to: maxOffset)
                return
            }

            // Set position
            webView.scrollView.setContentOffset(CGPoint(x: webView.scrollView.contentOffset.x, y: webView.scrollView.contentSize.height), animated: false)
            // Animated scroll
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseOut, animations: {
                webView.scrollView.setContentOffset(CGPoint(x: webView.scrollView.contentOffset.x, y: maxOffset), animated: false)
                webView.scrollView.s1_ignoringContentOffsetChangedToZero = true
                webView.scrollView.alpha = 1.0
            }, completion: { _ in
                webView.scrollView.s1_ignoringContentOffsetChangedToZero = false
                webView.scrollView.flashScrollIndicators()
            })
        case .toBottom:
            if webPageDidFinishFirstAutomaticScrolling {
                changeOffsetIfNeeded(to: maxOffset)
                return
            }

            webView.evaluateJavaScript("$('html, body').animate({ scrollTop: $(document).height()}, 300);", completionHandler: nil)
        case .restorePosition:
            // Restore last view position from cached position in this view controller.
            webView.scrollView.s1_ignoringContentOffsetChangedToZero = true
            if let positionForPage = viewModel.cachedOffsetForCurrentPage()?.aibo_clamped(to: 0.0...maxOffset) {
                S1LogInfo("[ContentVC] Trying to restore position of \(positionForPage)")

                changeOffsetIfNeeded(to: positionForPage)
            } else {
                changeOffsetIfNeeded(to: 0.0)
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

    func _updateDecorationLines(contentSize _: CGSize) {
        topDecorateLine.isHidden = viewModel.isInFirstPage() || !finishFirstLoading.value
        bottomDecorateLine.isHidden = !finishFirstLoading.value
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

    func refreshCurrentPage(forceUpdate: Bool, scrollType: ScrollType) {
        viewModel.cancelRequest() // ???: Maybe remove this?
        self.scrollType = scrollType
        _hook_preChangeCurrentPage()
        viewModel.currentPage.value = viewModel.currentPage.value
        fetchContentForCurrentPage(forceUpdate: forceUpdate)
    }

    func updateBackButtonAppearance(_ oldValue: BackButtonState) {
        switch (backButtonState, oldValue) {
        case let (.back(rotateAngle), .back(oldRotateAngle)) where rotateAngle != oldRotateAngle:
            backButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(Double.pi / 2 * rotateAngle), 0.0, 0.0, 1.0)

        case let (.back(rotateAngle), _):
            backButton.setImage(viewModel.backwardButtonImage(), for: .normal)
            backButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(Double.pi / 2 * rotateAngle), 0.0, 0.0, 1.0)
        }
    }

    func updateForwardButtonAppearance(_ oldValue: ForwardButtonState) {
        switch (forwardButtonState, oldValue) {
        case let (.forward(rotateAngle), .forward(oldRotateAngle)) where rotateAngle != oldRotateAngle:
            forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(Double.pi / 2 * rotateAngle), 0.0, 0.0, 1.0)
        case let (.forward(rotateAngle), _):
            forwardButton.setImage(viewModel.forwardButtonImage(), for: .normal)
            forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(Double.pi / 2 * rotateAngle), 0.0, 0.0, 1.0)
        case let (.refresh(rotateAngle), .refresh(oldRotateAngle)) where rotateAngle != oldRotateAngle:
            forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(Double.pi / 2 * rotateAngle), 0.0, 0.0, 1.0)
        case let (.refresh(rotateAngle), _):
            forwardButton.setImage(#imageLiteral(resourceName: "Refresh_black"), for: .normal)
            forwardButton.imageView?.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(Double.pi / 2 * rotateAngle), 0.0, 0.0, 1.0)
        }
    }

    func logCurrentPresentingViewController() {
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
