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
    var useTableView: Bool = false

    var tableView: UITableView?
    let webView = UIWebView()

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
        self.view.backgroundColor = APColorManager.shared.colorForKey("content.background")
        self.automaticallyAdjustsScrollViewInsets = false
        if self.useTableView {
            let tableView = UITableView()
            self.tableView = tableView
            tableView.backgroundColor = APColorManager.shared.colorForKey("content.background")
            tableView.delegate = self
            tableView.dataSource = self
            tableView.rowHeight = UITableViewAutomaticDimension
            tableView.estimatedRowHeight = 100.0
            tableView.separatorStyle = .none
            tableView.register(QuoteFloorCell.self, forCellReuseIdentifier: "QuoteCell")
            self.view.addSubview(tableView)

            tableView.snp.makeConstraints({ (make) -> Void in
                make.top.equalTo(self.topLayoutGuide.snp.bottom)
                make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
                make.leading.trailing.equalTo(self.view)
            })
        } else {
            webView.isOpaque = false
            webView.backgroundColor = APColorManager.shared.colorForKey("content.webview.background")
            webView.delegate = self
            webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
            self.view.addSubview(webView)

            webView.snp.makeConstraints({ (make) -> Void in
                make.top.equalTo(self.topLayoutGuide.snp.bottom)
                make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
                make.leading.trailing.equalTo(self.view)
            })
            webView.loadHTMLString(self.viewModel.htmlString, baseURL: self.viewModel.baseURL as URL)
        }
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Crashlytics.sharedInstance().setObjectValue("QuoteViewController", forKey: "lastViewController")
    }

    deinit {
        DDLogInfo("[QuoteFloorVC] dealloc")
    }

}

// MARK: - Table View Delegate
extension S1QuoteFloorViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSection()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRow(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "QuoteCell", for: indexPath) as! QuoteFloorCell
        cell.configure(viewModel.presenting(at: indexPath))
        tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        return cell
    }
}

extension S1QuoteFloorViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

// MARK: - WebView Delegate
extension S1QuoteFloorViewController: UIWebViewDelegate {
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
        offset.y = computedOffset.limit(0.0, to: webView.scrollView.contentSize.height - webView.scrollView.bounds.height)
        webView.scrollView.contentOffset = offset
    }

    // MARK: Helper
    func topPositionOfMessageWithId(_ elementID: Int) -> CGFloat {
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
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return APColorManager.shared.isDarkTheme() ? .lightContent : .default
    }
}
