//
//  S1WebViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 5/18/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjack

class S1WebViewController: UIViewController, UIWebViewDelegate {
    var URLToOpen: NSURL

    let blurBackgroundView = UIVisualEffectView(effect:nil)

    let titleLabel = UILabel(frame: CGRect.zero)
    let vibrancyEffectView = UIVisualEffectView(effect:nil)
    let webView = UIWebView(frame: CGRect.zero)
    let statusBarOverlayView = UIVisualEffectView(effect:nil)
    let statusBarSeparatorView = UIView(frame: CGRect.zero)
    let toolBar = UIToolbar(frame: CGRect.zero)
    var backButtonItem: UIBarButtonItem?
    var forwardButtonItem: UIBarButtonItem?
    var refreshButtonItem: UIBarButtonItem?
    var stopButtonItem: UIBarButtonItem?
    var safariButtonItem: UIBarButtonItem?
    var closeButtonItem: UIBarButtonItem?

    // MARK: - Life Cycle
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

        self.view.backgroundColor = nil
        self.webView.backgroundColor = nil
        self.webView.delegate = self
        self.webView.scalesPageToFit = true

        self.statusBarSeparatorView.backgroundColor = UIColor.blackColor()

        self.view.addSubview(blurBackgroundView)
        blurBackgroundView.snp_makeConstraints { (make) in
            make.edges.equalTo(self.view)
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

        self.view.addSubview(webView)
        self.view.addSubview(statusBarOverlayView)
        self.view.addSubview(statusBarSeparatorView)
        self.view.addSubview(toolBar)

        webView.snp_makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }

        statusBarOverlayView.snp_makeConstraints { (make) in
            make.top.equalTo(self.snp_topLayoutGuideTop)
            make.leading.trailing.equalTo(self.view)
            make.bottom.equalTo(self.snp_topLayoutGuideBottom)
        }

        statusBarSeparatorView.snp_makeConstraints { (make) in
            make.top.equalTo(statusBarOverlayView.snp_bottom)
            make.leading.trailing.equalTo(statusBarOverlayView)
            make.height.equalTo(1.0 / UIScreen.mainScreen().scale)
        }

        toolBar.snp_makeConstraints { (make) in
            make.bottom.equalTo(self.view.snp_bottom)
            make.leading.trailing.equalTo(self.view)
        }

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(S1WebViewController.didReceivePaletteChangeNotification(_:)), name: "S1PaletteDidChangeNotification", object: nil)

        webView.loadRequest(NSURLRequest(URL: self.URLToOpen))
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        self.webView.stopLoading()
        self.webView.delegate = nil
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.didReceivePaletteChangeNotification(NSNotification(name: "", object: nil))
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        webView.scrollView.contentInset = UIEdgeInsets(top: statusBarSeparatorView.frame.maxY - webView.frame.minY, left: 0.0, bottom: webView.frame.maxY - toolBar.frame.minY, right: 0.0)
        webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset
    }
    // MARK: UIWebViewDelegate
    func webViewDidStartLoad(webView: UIWebView) {
        updateBarItems()
        backButtonItem?.enabled = webView.canGoBack
        forwardButtonItem?.enabled = webView.canGoForward
        titleLabel.text = currentValidURL().absoluteString
    }

    func webViewDidFinishLoad(webView: UIWebView) {
        updateBarItems()
        backButtonItem?.enabled = webView.canGoBack
        forwardButtonItem?.enabled = webView.canGoForward
        titleLabel.text = currentValidURL().absoluteString
    }

    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        updateBarItems()
    }

    // MARK: Toolbar
    func updateBarItems() {
        guard let
            back = self.backButtonItem,
            forward = self.forwardButtonItem,
            refresh = self.refreshButtonItem,
            stop = self.stopButtonItem,
            close = self.closeButtonItem,
            safari = self.safariButtonItem else { return }

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        let refreshOrStopItem = webView.loading ? stop : refresh
        toolBar.setItems([close, flexSpace, back, flexSpace, refreshOrStopItem, flexSpace, forward, flexSpace, safari], animated: true)
    }

    // MARK: Actions
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

    private func currentValidURL() -> NSURL {
        if let URL = webView.request?.URL where URL.absoluteString != "" {
            return URL
        } else {
            return self.URLToOpen
        }
    }

    func didReceivePaletteChangeNotification(notification: NSNotification) {
        statusBarSeparatorView.backgroundColor = APColorManager.sharedInstance.colorForKey("default.text.tint")

        if APColorManager.sharedInstance.isDarkTheme() {
            let darkBlurEffect = UIBlurEffect(style: .Dark)
            blurBackgroundView.effect = darkBlurEffect
            vibrancyEffectView.effect = UIVibrancyEffect(forBlurEffect: darkBlurEffect)
            statusBarOverlayView.effect = darkBlurEffect
            toolBar.barStyle = .Black
        } else {
            let lightBlurEffect = UIBlurEffect(style: .ExtraLight)
            blurBackgroundView.effect = lightBlurEffect
            vibrancyEffectView.effect = UIVibrancyEffect(forBlurEffect: lightBlurEffect)
            statusBarOverlayView.effect = UIBlurEffect(style: .ExtraLight)
            toolBar.barStyle = .Default
        }
    }
}
