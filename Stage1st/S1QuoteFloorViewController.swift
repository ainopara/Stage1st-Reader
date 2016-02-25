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

class S1QuoteFloorViewController: UIViewController {
    var htmlString: String?
    var topic: S1Topic?
    var floors: [S1Floor]?
    var useTableView: Bool = false
    var centerFloorID: Int = 0
    
    var tableView: UITableView?
    var webView: UIWebView?
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = APColorManager.sharedInstance.colorForKey("content.background")
        if (self.useTableView) {
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
                make.left.equalTo(self.view.snp_left)
                make.right.equalTo(self.view.snp_right)
            })
        } else {
            let webView = UIWebView()
            self.webView = webView
            webView.dataDetectorTypes = .None;
            webView.opaque = false;
            webView.backgroundColor = APColorManager.sharedInstance.colorForKey("content.webview.background")
            webView.delegate = self
            webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
            self.view.addSubview(webView)
            webView.snp_makeConstraints(closure: { (make) -> Void in
                make.top.equalTo(self.snp_topLayoutGuideBottom)
                make.bottom.equalTo(self.snp_bottomLayoutGuideTop)
                make.left.equalTo(self.view.snp_left)
                make.right.equalTo(self.view.snp_right)
            })
            if let theHtmlString = self.htmlString {
                webView.loadHTMLString(theHtmlString, baseURL: NSURL())
            }
        }
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        Crashlytics.sharedInstance().setObjectValue("QuoteViewController", forKey: "lastViewController")
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
        let cell: S1QuoteFloorCell = tableView.dequeueReusableCellWithIdentifier("QuoteCell") as? S1QuoteFloorCell ?? S1QuoteFloorCell(style:.Default,reuseIdentifier:"QuoteCell")
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
        if URL.absoluteString == "about:blank" {
            return true
        }
        return false
    }

    func webViewDidFinishLoad(webView: UIWebView) {
        var offset = webView.scrollView.contentOffset
        var computedOffset: CGFloat = positionOfElementWithId(self.centerFloorID) - 32
        if computedOffset > webView.scrollView.contentSize.height - webView.scrollView.bounds.height {
            computedOffset = webView.scrollView.contentSize.height - webView.scrollView.bounds.height;
        }
        if computedOffset < 0 {
            computedOffset = 0
        }
        offset.y = computedOffset
        webView.scrollView.contentOffset = offset
    }

    // MARK: Helper
    func positionOfElementWithId(elementID: NSNumber) -> CGFloat {
        let result: String? = self.webView?.stringByEvaluatingJavaScriptFromString("function f(){ var r = document.getElementById('postmessage_\(elementID)').getBoundingClientRect(); return r.top; } f();")
        print(result, terminator: "")
        if let result1 = result , let result2 = Double(result1) {
            return CGFloat(result2)
        }
        return 0;
    }
}
