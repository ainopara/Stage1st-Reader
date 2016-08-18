//
//  S1WebViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 5/18/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import WebKit
import SnapKit
import CocoaLumberjack

class S1WebViewController: UIViewController, WKNavigationDelegate {
    var URLToOpen: NSURL

    let blurBackgroundView = UIVisualEffectView(effect:nil)

    let titleLabel = UILabel(frame: CGRect.zero)
    let vibrancyEffectView = UIVisualEffectView(effect:nil)
    let webView = WKWebView(frame: CGRect.zero, configuration: WKWebViewConfiguration())
    let progressView = UIProgressView(progressViewStyle: .Bar)
    let statusBarOverlayView = UIVisualEffectView(effect:nil)
    let statusBarSeparatorView = UIView(frame: CGRect.zero)
    let toolBar = UIToolbar(frame: CGRect.zero)
    var backButtonItem: UIBarButtonItem?
    var forwardButtonItem: UIBarButtonItem?
    var refreshButtonItem: UIBarButtonItem?
    var stopButtonItem: UIBarButtonItem?
    var safariButtonItem: UIBarButtonItem?
    var closeButtonItem: UIBarButtonItem?

    // MARK: -
    init(URL: NSURL) {
        self.URLToOpen = URL
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .OverFullScreen
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = nil

        webView.backgroundColor = .clearColor()
        webView.scrollView.backgroundColor = .clearColor()
        webView.opaque = false
        webView.navigationDelegate = self
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)

        statusBarSeparatorView.backgroundColor = UIColor.blackColor()

        view.addSubview(blurBackgroundView)
        blurBackgroundView.snp_makeConstraints { (make) in
            make.edges.equalTo(view)
        }

        blurBackgroundView.contentView.addSubview(vibrancyEffectView)
        vibrancyEffectView.snp_makeConstraints { (make) in
            make.leading.equalTo(blurBackgroundView.contentView.snp_leading).offset(10.0)
            make.trailing.equalTo(blurBackgroundView.contentView.snp_trailing).offset(-10.0)
            make.top.equalTo(blurBackgroundView.contentView.snp_top).offset(20.0 + 10.0) // TODO: adjust in viewDidLayoutSubviews()
        }

        titleLabel.numberOfLines = 0
        titleLabel.font = UIFont.systemFontOfSize(12.0)  // need a better solution
        titleLabel.textAlignment = .Center
        vibrancyEffectView.contentView.addSubview(titleLabel)
        titleLabel.snp_makeConstraints { (make) in
            make.edges.equalTo(vibrancyEffectView.contentView)
        }

        toolBar.barTintColor = nil

        backButtonItem = UIBarButtonItem(image: UIImage(named: "Back"), style: .Plain, target: self, action: #selector(S1WebViewController.back))
        forwardButtonItem = UIBarButtonItem(image: UIImage(named: "Forward"), style: .Plain, target: self, action: #selector(S1WebViewController.forward))
        refreshButtonItem = UIBarButtonItem(image: UIImage(named: "Refresh_black"), style: .Plain, target: self, action: #selector(S1WebViewController.refresh))
        stopButtonItem = UIBarButtonItem(image: UIImage(named: "Close"), style: .Plain, target: self, action: #selector(S1WebViewController.stop))
        safariButtonItem = UIBarButtonItem(image: UIImage(named: "Safari_s"), style: .Plain, target: self, action: #selector(S1WebViewController.openInSafari))
        closeButtonItem = UIBarButtonItem(image: UIImage(named: "Close"), style: .Plain, target: self, action: #selector(S1WebViewController.dismiss))

        updateBarItems()

        view.addSubview(webView)
        view.addSubview(statusBarOverlayView)
        view.addSubview(statusBarSeparatorView)
        view.addSubview(toolBar)
        view.addSubview(progressView)

        webView.snp_makeConstraints { (make) in
            make.edges.equalTo(view)
        }

        statusBarOverlayView.snp_makeConstraints { (make) in
            make.top.equalTo(snp_topLayoutGuideTop)
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(snp_topLayoutGuideBottom)
        }

        statusBarSeparatorView.snp_makeConstraints { (make) in
            make.top.equalTo(statusBarOverlayView.snp_bottom)
            make.leading.trailing.equalTo(statusBarOverlayView)
            make.height.equalTo(1.0 / UIScreen.mainScreen().scale)
        }

        toolBar.snp_makeConstraints { (make) in
            make.bottom.equalTo(view.snp_bottom)
            make.leading.trailing.equalTo(view)
        }

        progressView.snp_makeConstraints { (make) in
            make.leading.trailing.equalTo(toolBar)
            make.top.equalTo(toolBar.snp_top)
            make.height.equalTo(1.0)
        }


        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(S1WebViewController.didReceivePaletteChangeNotification(_:)), name: APPaletteDidChangeNotification, object: nil)

        webView.loadRequest(NSURLRequest(URL: URLToOpen))
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        self.webView.removeObserver(self, forKeyPath: "estimatedProgress", context: nil)
        self.webView.stopLoading()
//        self.webView.delegate = nil
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.didReceivePaletteChangeNotification(NSNotification(name: "", object: nil))
    }

    // MARK: Layout
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        webView.scrollView.contentInset = UIEdgeInsets(top: statusBarSeparatorView.frame.maxY - webView.frame.minY, left: 0.0, bottom: webView.frame.maxY - toolBar.frame.minY, right: 0.0)
        webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset
    }

    // MARK: - Actions
    func dismiss() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    func back() {
        webView.goBack()
    }

    func forward() {
        webView.goForward()
    }

    func refresh() {
        webView.reload()
    }

    func stop() {
        webView.stopLoading()

        updateBarItems()
    }

    func openInSafari() {
        let URLToOpenInSafari = currentValidURL()
        DDLogDebug("[WebViewController] open in safari:\(URLToOpenInSafari)")
        if UIApplication.sharedApplication().openURL(URLToOpenInSafari) != true {
            DDLogError("[WebViewController] failed to open \(URLToOpenInSafari) in safari")
        }
    }

    // MARK: - UIWebViewDelegate
    func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation!) {
        DDLogDebug("[WebViewController] didCommit")
        updateBarItems()
        backButtonItem?.enabled = webView.canGoBack
        forwardButtonItem?.enabled = webView.canGoForward
        titleLabel.text = currentValidURL().absoluteString
    }

    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        DDLogDebug("[WebViewController] didFinish")
        updateBarItems()
        backButtonItem?.enabled = webView.canGoBack
        forwardButtonItem?.enabled = webView.canGoForward
        titleLabel.text = currentValidURL().absoluteString
    }

    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        DDLogDebug("[WebViewController] didFail")
        updateBarItems()
    }

    // MARK: KVO
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard let newProgress = change?[NSKeyValueChangeNewKey] as? Float else { return }
        DDLogVerbose("[WebViewController] Loading progress: \(newProgress)")

        if newProgress == 1.0 {
            UIView.animateWithDuration(0.3, animations: {
                self.progressView.setProgress(newProgress, animated: false)
                self.progressView.alpha = 0.0
            }, completion: { finished in
                self.progressView.setProgress(0.0, animated: false)
            })
        } else {
            self.progressView.setProgress(newProgress, animated: true)
            self.progressView.alpha = 1.0
        }
    }

    // MARK: - Helper
    private func updateBarItems() {
        guard let
            back = self.backButtonItem,
            forward = self.forwardButtonItem,
            refresh = self.refreshButtonItem,
//            stop = self.stopButtonItem,
            close = self.closeButtonItem,
            safari = self.safariButtonItem else { return }

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
//        let refreshOrStopItem = webView.loading ? stop : refresh
        let refreshOrStopItem = refresh // always show refresh button until we have a new icon for stop item.
        toolBar.setItems([close, flexSpace, back, flexSpace, refreshOrStopItem, flexSpace, forward, flexSpace, safari], animated: true)
    }

    private func currentValidURL() -> NSURL {
        if let URL = webView.URL where URL.absoluteString != "" {
            return URL
        } else {
            return self.URLToOpen
        }
    }

    // MARK: - Notification
    func didReceivePaletteChangeNotification(notification: NSNotification) {
        statusBarSeparatorView.backgroundColor = APColorManager.sharedInstance.colorForKey("default.text.tint")
        progressView.tintColor = APColorManager.sharedInstance.colorForKey("default.text.tint")

        if APColorManager.sharedInstance.isDarkTheme() {
            let darkBlurEffect = UIBlurEffect(style: .Dark)
            blurBackgroundView.effect = darkBlurEffect
            vibrancyEffectView.effect = UIVibrancyEffect(forBlurEffect: darkBlurEffect)
            statusBarOverlayView.effect = darkBlurEffect
            toolBar.barStyle = .Black
        } else {
            let lightBlurEffect = UIBlurEffect(style: .Light)
            blurBackgroundView.effect = lightBlurEffect
            vibrancyEffectView.effect = UIVibrancyEffect(forBlurEffect: UIBlurEffect(style: .Light))
            statusBarOverlayView.effect = UIBlurEffect(style: .ExtraLight)
            toolBar.barStyle = .Default
        }
    }
}
