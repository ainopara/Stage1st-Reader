//
//  S1QuoteFloorViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 7/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

import WebKit
import Crashlytics
import CocoaLumberjack
import JTSImageViewController

class S1QuoteFloorViewController: UIViewController {
    let viewModel: QuoteFloorViewModel

    lazy var webView: WKWebView = {
        return WKWebView(frame: .zero, configuration: self.sharedConfiguration())
    }()

    init(viewModel: QuoteFloorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        automaticallyAdjustsScrollViewInsets = false

        webView.navigationDelegate = self
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        webView.scrollView.delegate = self
        webView.isOpaque = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(webView)
        webView.snp.makeConstraints({ (make) -> Void in
            make.top.equalTo(self.topLayoutGuide.snp.bottom)
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
            make.leading.trailing.equalTo(self.view)
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        didReceivePaletteChangeNotification(nil)

        // defer from initializer to here to make sure navigationController exist (i.e. self be added to navigation stack)
        // FIXME: find a way to make sure this only called once.
        if let colorPanRecognizer = (self.navigationController?.delegate as? NavigationControllerDelegate)?.colorPanRecognizer {
            webView.scrollView.panGestureRecognizer.require(toFail: colorPanRecognizer)
        }
//        if let panRecognizer = (self.navigationController?.delegate as? NavigationControllerDelegate)?.panRecognizer {
//            webView.scrollView.panGestureRecognizer.require(toFail: panRecognizer)
//        }

        // http://stackoverflow.com/questions/27809259/detecting-whether-a-wkwebview-has-blanked
        // Also use this method to initialize content.
        webView.evaluateJavaScript("document.querySelector('body').innerHTML") { [weak self] (result, error) in
            guard let strongSelf = self else { return }
            guard let result = result as? String, result != "" else {
                strongSelf.webView.loadHTMLString(strongSelf.viewModel.generatePage(with: strongSelf.viewModel.floors), baseURL: strongSelf.viewModel.baseURL)
                return
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Crashlytics.sharedInstance().setObjectValue("QuoteViewController", forKey: "lastViewController")
    }

    deinit {
        DDLogInfo("[QuoteFloorVC] dealloc")
    }
}

// MARK: - Actions
extension S1QuoteFloorViewController {
    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        view.backgroundColor = APColorManager.shared.colorForKey("content.background")
        webView.backgroundColor = APColorManager.shared.colorForKey("content.webview.background")

        setNeedsStatusBarAppearanceUpdate()

    }
}

// MARK:
extension S1QuoteFloorViewController {
    func sharedConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "stage1st")
        configuration.userContentController = userContentController
        return configuration
    }
}

// MARK: - WKScriptMessageHandler
extension S1QuoteFloorViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

    }
}

// MARK: WKNavigationDelegate
extension S1QuoteFloorViewController: WKNavigationDelegate {
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let URL = request.url else {
            return false
        }

        if URL.absoluteString == "about:blank" || URL.absoluteString.hasPrefix("file://") {
            return true
        }

        return false
    }

    func webViewDidFinishLoad(_ webView: UIWebView) {
        let computedOffset: CGFloat = topPositionOfMessageWithId(self.viewModel.centerFloorID) - 32
        var offset = webView.scrollView.contentOffset
        offset.y = computedOffset.s1_limit(0.0, to: webView.scrollView.contentSize.height - webView.scrollView.bounds.height)
        webView.scrollView.contentOffset = offset
    }
}

extension S1QuoteFloorViewController: UIScrollViewDelegate {
    // To disable pinch to zoom gesture in WKWebView
    open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }

    // To fix bug in WKWebView
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
    }
}

// MARK: Helper
extension S1QuoteFloorViewController {
    func topPositionOfMessageWithId(_ elementID: Int) -> CGFloat {
        if let rect = webView.s1_positionOfElement(with: "postmessage_\(elementID)") {
            return rect.minY
        } else {
            DDLogError("[QuoteFloorVC] Touch element ID: \(elementID) not found.")
            return 0.0
        }
    }
}

// MARK: - Style
extension S1QuoteFloorViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return APColorManager.shared.isDarkTheme() ? .lightContent : .default
    }
}
