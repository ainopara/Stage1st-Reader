//
//  S1QuoteFloorViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 7/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

import UIKit
import JTSImageViewController
import Crashlytics
import CocoaLumberjack

class S1QuoteFloorViewController: UIViewController {
    var htmlString: String?
    var pageURL: NSURL?
    var topic: S1Topic?
    var floors: [S1Floor]?
    var useTableView: Bool = true
    var centerFloorID: Int = 0

    var tableView: UITableView?
    var webView = UIWebView()
    let viewModel: QuoteFloorViewModel

    init(viewModel: QuoteFloorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = APColorManager.sharedInstance.colorForKey("content.background")
        self.automaticallyAdjustsScrollViewInsets = false
        if self.useTableView {
            let tableView = UITableView()
            self.tableView = tableView
            tableView.backgroundColor = APColorManager.sharedInstance.colorForKey("content.background")
            tableView.delegate = self
            tableView.dataSource = self
            tableView.rowHeight = UITableViewAutomaticDimension
            tableView.estimatedRowHeight = 100.0
            tableView.separatorStyle = .None
            tableView.registerClass(QuoteFloorCell.self, forCellReuseIdentifier: "QuoteCell")
            self.view.addSubview(tableView)

            tableView.snp_makeConstraints(closure: { (make) -> Void in
                make.top.equalTo(self.snp_topLayoutGuideBottom)
                make.bottom.equalTo(self.snp_bottomLayoutGuideTop)
                make.leading.trailing.equalTo(self.view)
            })
        } else {
            webView.dataDetectorTypes = .None
            webView.opaque = false
            webView.backgroundColor = APColorManager.sharedInstance.colorForKey("content.webview.background")
            webView.delegate = self
            webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
            self.view.addSubview(webView)

            webView.snp_makeConstraints(closure: { (make) -> Void in
                make.top.equalTo(self.snp_topLayoutGuideBottom)
                make.bottom.equalTo(self.snp_bottomLayoutGuideTop)
                make.leading.trailing.equalTo(self.view)
            })
            if let theHtmlString = self.htmlString {
                webView.loadHTMLString(theHtmlString, baseURL: pageURL)
            }
        }
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        Crashlytics.sharedInstance().setObjectValue("QuoteViewController", forKey: "lastViewController")
    }

    deinit {
        DDLogInfo("[QuoteFloorVC] dealloc")
    }

}

// MARK: - Table View Delegate
extension S1QuoteFloorViewController: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return viewModel.numberOfSection()
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRow(in: section)
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("QuoteCell", forIndexPath: indexPath) as! QuoteFloorCell
        cell.configure(viewModel.presenting(at: indexPath))
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        return cell
    }
}

extension S1QuoteFloorViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
}

// MARK: - WebView Delegate
extension S1QuoteFloorViewController: UIWebViewDelegate {
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let URL = request.URL else {
            return false
        }

        if URL.absoluteString == "about:blank" || URL.absoluteString.hasPrefix("file://") {
            return true
        }

        return false
    }

    func webViewDidFinishLoad(webView: UIWebView) {
        let computedOffset: CGFloat = topPositionOfMessageWithId(self.centerFloorID) - 32
        var offset = webView.scrollView.contentOffset
        offset.y = computedOffset.limit(0.0, to: webView.scrollView.contentSize.height - webView.scrollView.bounds.height)
        webView.scrollView.contentOffset = offset
    }

    // MARK: Helper
    func topPositionOfMessageWithId(elementID: Int) -> CGFloat {
        if let rect = webView.s1_positionOfElementWithId("postmessage_\(elementID)") {
            return rect.minY
        } else {
            DDLogError("[QuoteFloorVC] Touch element ID: \(elementID) not found.")
            return 0.0
        }
    }
}

// MARK: - Style
extension S1QuoteFloorViewController {
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .LightContent : .Default
    }
}

extension CGFloat {
    func limit(from: CGFloat, to: CGFloat) -> CGFloat {
        assert(to >= from)
        let result = self < to ? self : to
        return result > from ? result : from
    }
}
