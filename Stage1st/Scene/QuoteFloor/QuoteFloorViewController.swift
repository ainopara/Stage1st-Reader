//
//  QuoteFloorViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 7/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

import WebKit
import Crashlytics
import CocoaLumberjack
import JTSImageViewController
import Photos

class QuoteFloorViewController: UIViewController, ImagePresenter, UserPresenter, ContentPresenter {
    let viewModel: QuoteFloorViewModel

    lazy var webView: WKWebView = {
        WKWebView(frame: .zero, configuration: self.sharedWKWebViewConfiguration())
    }()

    var presentType: PresentType = .none {
        didSet {
            switch presentType {
            case .none:
                Crashlytics.sharedInstance().setObjectValue("QuoteViewController", forKey: "lastViewController")
            case .image:
                Crashlytics.sharedInstance().setObjectValue("ImageViewController", forKey: "lastViewController")
            default:
                break
            }
        }
    }

    init(viewModel: QuoteFloorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        automaticallyAdjustsScrollViewInsets = false

        webView.navigationDelegate = self
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.decelerationRate = UIScrollView.DecelerationRate.normal
        webView.scrollView.delegate = self
        webView.isOpaque = false

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
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
            selector: #selector(didReceiveUserBlockStatusDidChangedNotification(_:)),
            name: .UserBlockStatusDidChangedNotification,
            object: nil
        )
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        S1LogInfo("[QuoteFloorVC] Dealloc Begin")
        NotificationCenter.default.removeObserver(self)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "stage1st")
        webView.scrollView.delegate = nil
        webView.stopLoading()
        S1LogInfo("[QuoteFloorVC] Dealloced")
    }
}

// MARK: - Life Cycle

extension QuoteFloorViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(webView)
        webView.snp.makeConstraints({ (make) -> Void in
            make.top.equalTo(self.topLayoutGuide.snp.bottom)
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
            make.leading.trailing.equalTo(self.view)
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presentType = .none

        // defer from initializer to here to make sure navigationController exist (i.e. self be added to navigation stack)
        // FIXME: find a way to make sure this only called once. Prefer this not work.
        if let colorPanRecognizer = (navigationController?.delegate as? NavigationControllerDelegate)?.colorPanRecognizer {
            webView.scrollView.panGestureRecognizer.require(toFail: colorPanRecognizer)
        }

        didReceivePaletteChangeNotification(nil)

        tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated()
    }

    @objc func applicationWillEnterForeground() {
        S1LogDebug("[QuoteFloorVC] \(self) will enter foreground begin")
        tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated()
        S1LogDebug("[QuoteFloorVC] \(self) will enter foreground end")
    }
}

// MARK: - Actions

extension QuoteFloorViewController {
    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        view.backgroundColor = AppEnvironment.current.colorManager.colorForKey("content.background")
        webView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("content.webview.background")

        setNeedsStatusBarAppearanceUpdate()

        if notification != nil {
            webView.loadHTMLString(viewModel.generatePage(with: viewModel.floors), baseURL: viewModel.baseURL)
        }
    }

    @objc open func didReceiveUserBlockStatusDidChangedNotification(_: Notification?) {
        webView.loadHTMLString(viewModel.generatePage(with: viewModel.floors), baseURL: viewModel.baseURL)
    }
}

// MARK:

extension QuoteFloorViewController {
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

// MARK: - WKScriptMessageHandler

extension QuoteFloorViewController: WebViewEventDelegate {
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, actionButtonTappedFor _: Int) {
        //        actionButtonTapped(for: floorID)
    }
}

// MARK: JTSImageViewControllerInteractionsDelegate

extension QuoteFloorViewController: JTSImageViewControllerInteractionsDelegate {
    func imageViewerDidLongPress(_ imageViewer: JTSImageViewController!, at rect: CGRect) {
        let imageActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        imageActionSheet.addAction(UIAlertAction(title: NSLocalizedString("ImageViewController.ActionSheet.Save", comment: "Save"), style: .default, handler: { _ in
            DispatchQueue.global(qos: .background).async {
                PHPhotoLibrary.requestAuthorization { status in
                    guard case .authorized = status else {
                        S1LogError("No auth to access photo library")
                        return
                    }

                    guard let imageData = imageViewer.imageData else {
                        S1LogError("Image data is nil")
                        return
                    }

                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: nil)
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

extension QuoteFloorViewController: JTSImageViewControllerOptionsDelegate {
    func alphaForBackgroundDimmingOverlay(inImageViewer _: JTSImageViewController!) -> CGFloat {
        return 0.3
    }
}

// MARK: WKNavigationDelegate

extension QuoteFloorViewController: WKNavigationDelegate {

    func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if url.absoluteString.hasPrefix("file://") {
            if url.absoluteString.hasSuffix("html") {
                decisionHandler(.allow)
                return
            }
        }

        // Image URL opened in image Viewer
        if url.absoluteString.hasSuffix(".jpg") || url.absoluteString.hasSuffix(".gif") || url.absoluteString.hasSuffix(".png") {
            Answers.logCustomEvent(withName: "Inspect Image", customAttributes: [
                "type": "hijack",
                "source": "QuoteFloor",
            ])
            showImageViewController(transitionSource: .offScreen, imageURL: url)
            decisionHandler(.cancel)
            return
        }

        if AppEnvironment.current.serverAddress.hasSameDomain(with: url) {
            // Open as S1 topic
            if let topic = S1Parser.extractTopicInfo(fromLink: url.absoluteString) {
                var topic = topic
                if let tracedTopic = AppEnvironment.current.dataCenter.traced(topicID: topic.topicID.intValue) {
                    let lastViewedPage = topic.lastViewedPage
                    topic = tracedTopic.copy() as! S1Topic
                    if lastViewedPage != nil {
                        topic.lastViewedPage = lastViewedPage
                    }
                }

                Answers.logCustomEvent(withName: "Open Topic Link", customAttributes: [
                    "source": "QuoteFloor",
                ])
                showContentViewController(topic: topic)
                decisionHandler(.cancel)
                return
            }
        }

        let openActionHandler: (UIAlertAction) -> Void = { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.presentType = .background
            S1LogDebug("[ContentVC] Open in Safari: \(url)")

            UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: { (success) in
                if !success {
                    S1LogWarn("Failed to open url: \(url)")
                }
            })
        }

        // Fallback Open link
        let alertViewController = UIAlertController(
            title: NSLocalizedString("ContentViewController.WebView.OpenLinkAlert.Title", comment: ""),
            message: url.absoluteString,
            preferredStyle: .alert
        )

        alertViewController.addAction(UIAlertAction(
            title: NSLocalizedString("ContentViewController.WebView.OpenLinkAlert.Cancel", comment: ""),
            style: .cancel,
            handler: nil)
        )

        alertViewController.addAction(UIAlertAction(
            title: NSLocalizedString("ContentViewController.WebView.OpenLinkAlert.Open", comment: ""),
            style: .default,
            handler: openActionHandler)
        )

        present(alertViewController, animated: true, completion: nil)

        S1LogWarn("no case match for url: \(url), fallback cancel")
        decisionHandler(.cancel)
        return
    }

    func webViewWebContentProcessDidTerminate(_: WKWebView) {
        S1LogError("[QuoteFloor] \(#function)")
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.topPositionOfMessageWithId(strongSelf.viewModel.centerFloorID, completion: { (topPosition) in
                let computedOffset: CGFloat = topPosition - 32.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    webView.evaluateJavaScript("$('html, body').animate({ scrollTop: \(computedOffset)}, 0);", completionHandler: nil)
                }
            })
        }
    }
}

// MARK: UIScrollViewDelegate

extension QuoteFloorViewController: UIScrollViewDelegate {
    // To fix bug in WKWebView
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.decelerationRate = UIScrollView.DecelerationRate.normal
    }
}

// MARK: - Helper

extension QuoteFloorViewController {
    func topPositionOfMessageWithId(_ elementID: Int, completion: @escaping (CGFloat) -> Void) {
        webView.s1_positionOfElement(with: "postmessage_\(elementID)") {
            if let rect = $0 {
                completion(rect.minY)
            } else {
                S1LogError("[QuoteFloorVC] Touch element ID: \(elementID) not found.")
                completion(0.0)
            }
        }
    }

    fileprivate func tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated() {
        guard let title = webView.title, title != "" else {
            webView.loadHTMLString(viewModel.generatePage(with: viewModel.floors), baseURL: viewModel.baseURL)
            return
        }
    }
}

// MARK: - Style

extension QuoteFloorViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
