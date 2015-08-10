//
//  S1QuoteFloorViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 7/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

import UIKit

class S1QuoteFloorViewController: UIViewController, UIWebViewDelegate {
    var htmlString :String?
    var centerFloorID :Int = 0
    @IBOutlet weak var webView: UIWebView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = S1ColorManager.sharedInstance().colorForKey("content.background")
        if let theHtmlStirng = self.htmlString {
            self.webView.dataDetectorTypes = .None;
            self.webView.opaque = false;
            self.webView.backgroundColor = S1ColorManager.sharedInstance().colorForKey("content.webview.background")
            self.webView.delegate = self
            self.webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
            self.webView.loadHTMLString(theHtmlString, baseURL: NSURL())
        }
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if request.URL!.absoluteString == "about:blank" {
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
    
    func positionOfElementWithId(elementID: NSNumber) -> CGFloat {
        let result: String? = self.webView.stringByEvaluatingJavaScriptFromString("function f(){ var r = document.getElementById('postmessage_\(elementID)').getBoundingClientRect(); return r.top; } f();")
        print(result)
        if let result1 = result , let result2 = Double(result1) {
            return CGFloat(result2)
        }
        return 0;
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
