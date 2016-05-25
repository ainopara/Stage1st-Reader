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
    var useTableView: Bool = false
    var centerFloorID: Int = 0

    var tableView: UITableView?
    var webView = UIWebView()

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
            tableView.separatorStyle = .None
            tableView.estimatedRowHeight = 100.0
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
extension S1QuoteFloorViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.floors?.count ?? 0
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: S1QuoteFloorCell = tableView.dequeueReusableCellWithIdentifier("QuoteCell") as? S1QuoteFloorCell ?? S1QuoteFloorCell(style:.Default, reuseIdentifier: "QuoteCell")
        let floor = self.floors![indexPath.row]
        let viewModel = FloorViewModel(floorModel: floor, topicModel: self.topic!)
        cell.updateWithViewModel(viewModel)

        return cell
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
        let computedOffset: CGFloat = positionOfElementWithId(self.centerFloorID) - 32
        var offset = webView.scrollView.contentOffset
        offset.y = computedOffset.limit(0.0, to: webView.scrollView.contentSize.height - webView.scrollView.bounds.height)
        webView.scrollView.contentOffset = offset
    }

    // MARK: Helper
    func positionOfElementWithId(elementID: NSNumber) -> CGFloat {
        let result: String? = self.webView.stringByEvaluatingJavaScriptFromString("function f(){ var r = document.getElementById('postmessage_\(elementID)').getBoundingClientRect(); return r.top; } f();")
        DDLogDebug("[QuoteFloorVC] Touch element ID: \(elementID)")
        if let result1 = result, result2 = Double(result1) {
            return CGFloat(result2)
        }
        return 0
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
