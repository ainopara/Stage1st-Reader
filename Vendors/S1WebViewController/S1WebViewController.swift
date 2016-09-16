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
    var URLToOpen: URL

    let blurBackgroundView = UIVisualEffectView(effect:nil)

    let titleLabel = UILabel(frame: CGRect.zero)
    let vibrancyEffectView = UIVisualEffectView(effect:nil)
    let webView = WKWebView(frame: CGRect.zero, configuration: WKWebViewConfiguration())
    let progressView = UIProgressView(progressViewStyle: .bar)
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
    init(URL: Foundation.URL) {
        self.URLToOpen = URL
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = nil

        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false
        webView.navigationDelegate = self
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)

        statusBarSeparatorView.backgroundColor = UIColor.black

        view.addSubview(blurBackgroundView)
        blurBackgroundView.snp.makeConstraints { (make) in
            make.edges.equalTo(view)
        }

        blurBackgroundView.contentView.addSubview(vibrancyEffectView)
        vibrancyEffectView.snp.makeConstraints { (make) in
            make.leading.equalTo(blurBackgroundView.contentView.snp.leading).offset(10.0)
            make.trailing.equalTo(blurBackgroundView.contentView.snp.trailing).offset(-10.0)
            make.top.equalTo(blurBackgroundView.contentView.snp.top).offset(20.0 + 10.0) // TODO: adjust in viewDidLayoutSubviews()
        }

        titleLabel.numberOfLines = 0
        titleLabel.font = UIFont.systemFont(ofSize: 12.0)  // need a better solution
        titleLabel.textAlignment = .center
        vibrancyEffectView.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.edges.equalTo(vibrancyEffectView.contentView)
        }

        toolBar.barTintColor = nil

        backButtonItem = UIBarButtonItem(image: UIImage(named: "Back"), style: .plain, target: self, action: #selector(S1WebViewController.back))
        forwardButtonItem = UIBarButtonItem(image: UIImage(named: "Forward"), style: .plain, target: self, action: #selector(S1WebViewController.forward))
        refreshButtonItem = UIBarButtonItem(image: UIImage(named: "Refresh_black"), style: .plain, target: self, action: #selector(S1WebViewController.refresh))
        stopButtonItem = UIBarButtonItem(image: UIImage(named: "Close"), style: .plain, target: self, action: #selector(S1WebViewController.stop))
        safariButtonItem = UIBarButtonItem(image: UIImage(named: "Safari_s"), style: .plain, target: self, action: #selector(S1WebViewController.openInSafari))
        closeButtonItem = UIBarButtonItem(image: UIImage(named: "Close"), style: .plain, target: self, action: #selector(S1WebViewController._dismiss))

        updateBarItems()

        view.addSubview(webView)
        view.addSubview(statusBarOverlayView)
        view.addSubview(statusBarSeparatorView)
        view.addSubview(toolBar)
        view.addSubview(progressView)

        webView.snp.makeConstraints { (make) in
            make.edges.equalTo(view)
        }

        statusBarOverlayView.snp.makeConstraints { (make) in
            make.top.equalTo(self.topLayoutGuide.snp.top)
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(self.topLayoutGuide.snp.bottom)
        }

        statusBarSeparatorView.snp.makeConstraints { (make) in
            make.top.equalTo(statusBarOverlayView.snp.bottom)
            make.leading.trailing.equalTo(statusBarOverlayView)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }

        toolBar.snp.makeConstraints { (make) in
            make.bottom.equalTo(view.snp.bottom)
            make.leading.trailing.equalTo(view)
        }

        progressView.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(toolBar)
            make.top.equalTo(toolBar.snp.top)
            make.height.equalTo(1.0)
        }


        NotificationCenter.default.addObserver(self, selector: #selector(S1WebViewController.didReceivePaletteChangeNotification(_:)), name: NSNotification.Name(rawValue: APPaletteDidChangeNotification), object: nil)

        webView.load(URLRequest(url: URLToOpen))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        self.webView.removeObserver(self, forKeyPath: "estimatedProgress", context: nil)
        self.webView.stopLoading()
//        self.webView.delegate = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.didReceivePaletteChangeNotification(nil)
    }

    // MARK: Layout
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        webView.scrollView.contentInset = UIEdgeInsets(top: statusBarSeparatorView.frame.maxY - webView.frame.minY, left: 0.0, bottom: webView.frame.maxY - toolBar.frame.minY, right: 0.0)
        webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset
    }

    // MARK: - Actions
    func _dismiss() {
        self.dismiss(animated: true, completion: nil)
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
        if UIApplication.shared.openURL(URLToOpenInSafari) != true {
            DDLogError("[WebViewController] failed to open \(URLToOpenInSafari) in safari")
        }
    }

    // MARK: - UIWebViewDelegate
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        DDLogDebug("[WebViewController] didCommit")
        updateBarItems()
        backButtonItem?.isEnabled = webView.canGoBack
        forwardButtonItem?.isEnabled = webView.canGoForward
        titleLabel.text = currentValidURL().absoluteString
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DDLogDebug("[WebViewController] didFinish")
        updateBarItems()
        backButtonItem?.isEnabled = webView.canGoBack
        forwardButtonItem?.isEnabled = webView.canGoForward
        titleLabel.text = currentValidURL().absoluteString
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DDLogDebug("[WebViewController] didFail with error:\(error)")
        updateBarItems()
    }

    // MARK: KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let newProgress = change?[NSKeyValueChangeKey.newKey] as? Float else { return }
        DDLogVerbose("[WebViewController] Loading progress: \(newProgress)")

        if newProgress == 1.0 {
            UIView.animate(withDuration: 0.3, animations: {
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
    fileprivate func updateBarItems() {
        guard
            let back = self.backButtonItem,
            let forward = self.forwardButtonItem,
            let refresh = self.refreshButtonItem,
//            stop = self.stopButtonItem,
            let close = self.closeButtonItem,
            let safari = self.safariButtonItem else { return }

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
//        let refreshOrStopItem = webView.loading ? stop : refresh
        let refreshOrStopItem = refresh // always show refresh button until we have a new icon for stop item.
        toolBar.setItems([close, flexSpace, back, flexSpace, refreshOrStopItem, flexSpace, forward, flexSpace, safari], animated: true)
    }

    fileprivate func currentValidURL() -> URL {
        if let URL = webView.url, URL.absoluteString != "" {
            return URL
        } else {
            return self.URLToOpen
        }
    }

    // MARK: - Notification
    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        statusBarSeparatorView.backgroundColor = APColorManager.sharedInstance.colorForKey("default.text.tint")
        progressView.tintColor = APColorManager.sharedInstance.colorForKey("default.text.tint")

        if APColorManager.sharedInstance.isDarkTheme() {
            let darkBlurEffect = UIBlurEffect(style: .dark)
            blurBackgroundView.effect = darkBlurEffect
            vibrancyEffectView.effect = UIVibrancyEffect(blurEffect: darkBlurEffect)
            statusBarOverlayView.effect = darkBlurEffect
            toolBar.barStyle = .black
        } else {
            let lightBlurEffect = UIBlurEffect(style: .light)
            blurBackgroundView.effect = lightBlurEffect
            vibrancyEffectView.effect = UIVibrancyEffect(blurEffect: UIBlurEffect(style: .light))
            statusBarOverlayView.effect = UIBlurEffect(style: .extraLight)
            toolBar.barStyle = .default
        }
    }
}
