//
//  WebViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 5/18/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import WebKit
import SnapKit
import CocoaLumberjack

class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    var URLToOpen: URL

    let blurBackgroundView = UIVisualEffectView(effect:nil)

    let titleLabel = UILabel(frame: .zero)
    let vibrancyEffectView = UIVisualEffectView(effect:nil)
    let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    let progressView = UIProgressView(progressViewStyle: .bar)
    let statusBarOverlayView = UIVisualEffectView(effect:nil)
    let statusBarSeparatorView = UIView(frame: .zero)
    let toolBar = UIToolbar(frame: .zero)
    var backButtonItem: UIBarButtonItem?
    var forwardButtonItem: UIBarButtonItem?
    var refreshButtonItem: UIBarButtonItem?
    var stopButtonItem: UIBarButtonItem?
    var safariButtonItem: UIBarButtonItem?
    var closeButtonItem: UIBarButtonItem?

    private var observations = [NSKeyValueObservation]()

    // MARK: - Life Cycle
    init(URL: URL) {
        self.URLToOpen = URL

        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .overFullScreen

        view.backgroundColor = nil

        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.indicatorStyle = .default
        webView.isOpaque = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        let progressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] (webView, change) in
            guard let strongSelf = self else { return }
            guard let newProgress = change.newValue else { return }
            DDLogVerbose("[WebVC] Loading progress: \(newProgress)")

            if newProgress == 1.0 {
                UIView.animate(withDuration: 0.3, animations: {
                    strongSelf.progressView.setProgress(Float(newProgress), animated: false)
                    strongSelf.progressView.alpha = 0.0
                }, completion: { _ in
                    strongSelf.progressView.setProgress(0.0, animated: false)
                })
            } else {
                strongSelf.progressView.setProgress(Float(newProgress), animated: true)
                strongSelf.progressView.alpha = 1.0
            }
        }
        observations.append(progressObserver)

        statusBarSeparatorView.backgroundColor = UIColor.black

        titleLabel.numberOfLines = 0
        titleLabel.font = UIFont.systemFont(ofSize: 12.0)  // need a better solution
        titleLabel.textAlignment = .center

        toolBar.barTintColor = nil

        backButtonItem = UIBarButtonItem(image: UIImage(named: "Back"), style: .plain, target: self, action: #selector(back))
        forwardButtonItem = UIBarButtonItem(image: UIImage(named: "Forward"), style: .plain, target: self, action: #selector(forward))
        refreshButtonItem = UIBarButtonItem(image: UIImage(named: "Refresh_black"), style: .plain, target: self, action: #selector(refresh))
        stopButtonItem = UIBarButtonItem(image: UIImage(named: "Close"), style: .plain, target: self, action: #selector(stop))
        safariButtonItem = UIBarButtonItem(image: UIImage(named: "Safari_s"), style: .plain, target: self, action: #selector(openInSafari))
        closeButtonItem = UIBarButtonItem(image: UIImage(named: "Close"), style: .plain, target: self, action: #selector(_dismiss))

        updateBarItems()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: .UIApplicationWillEnterForeground,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceivePaletteChangeNotification(_:)),
            name: .APPaletteDidChange,
            object: nil
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

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

        vibrancyEffectView.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.edges.equalTo(vibrancyEffectView.contentView)
        }

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

        if #available(iOS 11.0, *) {
            toolBar.snp.makeConstraints { (make) in
                make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
                make.leading.trailing.equalTo(view)
            }
        } else {
            toolBar.snp.makeConstraints { (make) in
                make.bottom.equalTo(view.snp.bottom)
                make.leading.trailing.equalTo(view)
            }
        }

        progressView.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(toolBar)
            make.top.equalTo(toolBar.snp.top)
            make.height.equalTo(1.0)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        for observation in observations {
            observation.invalidate()
        }
        webView.stopLoading()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.didReceivePaletteChangeNotification(nil)
        DDLogInfo("[WebVC] view will appear")

        tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated()
    }

    @objc func applicationWillEnterForeground() {
        DDLogDebug("[WebVC] \(self) will enter foreground begin")
        tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated()
    }

    // MARK: Layout
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if #available(iOS 11.0, *) {
            // Top part of the workaround is no more necessary since iOS 11.
            webView.scrollView.contentInset = UIEdgeInsets(
                top: 0.0,
                left: 0.0,
                bottom: toolBar.frame.height, // It seems in iOS 11.0, WKWebView will automatically add home indicator's height, so we should not include that parts in contentInset.
                right: 0.0
            )
            webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset
        } else {
            webView.scrollView.contentInset = UIEdgeInsets(
                top: statusBarSeparatorView.frame.maxY - webView.frame.minY,
                left: 0.0,
                bottom: webView.frame.maxY - toolBar.frame.minY,
                right: 0.0
            )
            webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset
        }
    }

    // MARK: - Actions
    @objc func _dismiss() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func back() {
        webView.goBack()
    }

    @objc func forward() {
        webView.goForward()
    }

    @objc func refresh() {
        webView.reload()
    }

    @objc func stop() {
        webView.stopLoading()

        updateBarItems()
    }

    @objc func openInSafari() {
        let URLToOpenInSafari = currentValidURL()
        DDLogDebug("[WebVC] open in safari:\(URLToOpenInSafari)")
        if UIApplication.shared.openURL(URLToOpenInSafari) != true {
            DDLogError("[WebVC] failed to open \(URLToOpenInSafari) in safari")
        }
    }

    // MARK: - WKWebViewNavigationDelegate
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        DDLogDebug("[WebVC] didCommit")
        updateBarItems()
        backButtonItem?.isEnabled = webView.canGoBack
        forwardButtonItem?.isEnabled = webView.canGoForward
        titleLabel.text = currentValidURL().absoluteString
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DDLogDebug("[WebVC] didFinish")
        updateBarItems()
        backButtonItem?.isEnabled = webView.canGoBack
        forwardButtonItem?.isEnabled = webView.canGoForward
        titleLabel.text = currentValidURL().absoluteString
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DDLogDebug("[WebVC] didFail with error:\(error)")
        updateBarItems()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        DDLogError("[WebVC] \(#function)")
    }

    // MARK: WKWebViewUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    // MARK: - Helper
    private func updateBarItems() {
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

    private func currentValidURL() -> URL {
        if let URL = webView.url, URL.absoluteString != "" {
            return URL
        } else {
            return self.URLToOpen
        }
    }

    private func tryToReloadWKWebViewIfPageIsBlankDueToWebKitProcessTerminated() {
        guard let title = webView.title, title != "" else {
            webView.load(URLRequest(url: currentValidURL()))
            return
        }
    }

    // MARK: - Notification
    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        statusBarSeparatorView.backgroundColor = ColorManager.shared.colorForKey("default.text.tint")
        progressView.tintColor = ColorManager.shared.colorForKey("default.text.tint")

        if ColorManager.shared.isDarkTheme() {
            let darkBlurEffect = UIBlurEffect(style: .dark)
            blurBackgroundView.effect = darkBlurEffect
            vibrancyEffectView.effect = UIVibrancyEffect(blurEffect: darkBlurEffect)
            statusBarOverlayView.effect = darkBlurEffect
            toolBar.barStyle = .black
        } else {
            let lightBlurEffect = UIBlurEffect(style: .light)
            blurBackgroundView.effect = lightBlurEffect
            vibrancyEffectView.effect = UIVibrancyEffect(blurEffect: lightBlurEffect)
            statusBarOverlayView.effect = UIBlurEffect(style: .extraLight)
            toolBar.barStyle = .default
        }
    }
}
