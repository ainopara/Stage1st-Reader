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

    let blurBackgroundView = UIVisualEffectView(effect:UIBlurEffect(style: .Light))
    let webView = UIWebView(frame: CGRect.zero)
    let statusBarOverlayView = UIVisualEffectView(effect:UIBlurEffect(style: .ExtraLight))
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
    }

    func webViewDidFinishLoad(webView: UIWebView) {
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
        if webView.loading {
            toolBar.setItems([close, flexSpace, back, flexSpace, stop, flexSpace, forward, flexSpace, safari], animated: true)
        } else {
            toolBar.setItems([close, flexSpace, back, flexSpace, refresh, flexSpace, forward, flexSpace, safari], animated: true)
        }
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
    }

    func openInSafari() {
        let URLToOpenInSafari: NSURL
        if let URL = webView.request?.URL where URL.absoluteString != "" {
            URLToOpenInSafari = URL
        } else {
            URLToOpenInSafari = self.URLToOpen
        }

        DDLogDebug("[WebViewController] open in safari:\(URLToOpenInSafari)")
        if UIApplication.sharedApplication().openURL(URLToOpenInSafari) != true {
            DDLogError("[WebViewController] failed to open \(URLToOpenInSafari) in safari")
        }
    }

    func didReceivePaletteChangeNotification(notification: NSNotification) {
        if APColorManager.sharedInstance.isDarkTheme() {
            blurBackgroundView.effect = UIBlurEffect(style: .Dark)
            statusBarOverlayView.effect = UIBlurEffect(style: .Dark)
            toolBar.barStyle = .Black
        } else {
            blurBackgroundView.effect = UIBlurEffect(style: .Light)
            statusBarOverlayView.effect = UIBlurEffect(style: .ExtraLight)
            toolBar.barStyle = .Default
        }
    }
}
