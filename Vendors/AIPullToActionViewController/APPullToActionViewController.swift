//
//  APPullToActionViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 6/22/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

import UIKit

@objc protocol APPullToActionDelagete {
    optional func scrollViewDidEndDraggingOutsideTopBoundWithOffset(offset : CGFloat)
    optional func scrollViewDidEndDraggingOutsideBottomBoundWithOffset(offset : CGFloat)
    optional func scrollViewContentSizeDidChange(contentSize: CGSize)
    optional func scrollViewContentOffsetProgress(progress: [String: Double])
}

@objc enum APOffsetBaseLine: Int {
    case Top, Bottom, Left, Right
}

private struct APOffsetRange {
    let beginPosition: Double
    let endPosition: Double
    let baseLine: APOffsetBaseLine
    
    func progress (offset: Double) -> Double {
        return (offset - beginPosition) / (endPosition - beginPosition)
    }
}

class APPullToActionViewController: UIViewController, UIScrollViewDelegate {
    weak var scrollView : UIScrollView!
    weak var delegate : APPullToActionDelagete?
    
    var offset : CGPoint = CGPoint(x: 0, y: 0)
    var size : CGSize = CGSize(width: 0, height: 0)
    var inset : UIEdgeInsets = UIEdgeInsetsZero
    private var progressAction : [String: APOffsetRange] = Dictionary<String, APOffsetRange>()
    
    init(scrollView : UIScrollView) {
        self.scrollView = scrollView
        super.init(nibName: nil, bundle: nil)
        
        progressAction.updateValue(APOffsetRange(beginPosition: 0, endPosition: -80, baseLine: .Top), forKey: "top")
        progressAction.updateValue(APOffsetRange(beginPosition: 0, endPosition: 80, baseLine: .Bottom), forKey: "bottom")
        
        scrollView.delegate = self
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: NSKeyValueObservingOptions.New, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentSize", options: NSKeyValueObservingOptions.New, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentInset", options: NSKeyValueObservingOptions.New, context: nil)
        
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.scrollView.removeObserver(self, forKeyPath: "contentOffset")
        self.scrollView.removeObserver(self, forKeyPath: "contentSize")
        self.scrollView.removeObserver(self, forKeyPath: "contentInset")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if keyPath == "contentOffset" {
            self.offset = change["new"]?.CGPointValue() ?? self.offset
            if let delegateFunction = self.delegate?.scrollViewContentOffsetProgress {
                var progress : [String: Double] = Dictionary<String, Double>()
                for (name, actionOffset) in self.progressAction {
                    let progressValue = actionOffset.progress(self.baseLineOffset(actionOffset.baseLine))
                    progress.updateValue(progressValue, forKey: name)
                }
                delegateFunction(progress)
            }
            //println("contentOffset: \(self.offset)")
        }
        if keyPath == "contentSize" {
            self.size = change["new"]?.CGSizeValue() ?? self.size
            //println("size:w: \(self.size.width) h:\(self.size.height)")
            self.delegate?.scrollViewContentSizeDidChange?(self.size)
        }
        if keyPath == "contentInset" {
            self.inset = change["new"]?.UIEdgeInsetsValue() ?? self.inset
            //println("inset: top: \(self.inset.top) bottom: \(self.inset.bottom)")
        }
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if self.offset.y < 0 {
            println("end dragging <- \(self.offset.y)")
            self.delegate?.scrollViewDidEndDraggingOutsideTopBoundWithOffset?(self.offset.y)
            return
        }
        let bottomOffset = self.offset.y + self.scrollView.bounds.height - self.size.height //TODO: consider content inset
        if bottomOffset > 0 {
            println("end dragging -> \(bottomOffset)")
            self.delegate?.scrollViewDidEndDraggingOutsideBottomBoundWithOffset?(bottomOffset)
            return
        }
    }
    
    private func baseLineOffset(baseLine: APOffsetBaseLine) -> Double {
        switch baseLine {
        case .Top:
            return Double(self.offset.y)
        case .Bottom:
            var temp = self.scrollView.bounds.height - self.size.height
            if temp > 0 { temp = 0 }
            return Double(self.offset.y + temp)
        case .Left:
            return Double(self.offset.x)
        case .Right:
            var temp = self.scrollView.bounds.width - self.size.width
            if temp > 0 { temp = 0 }
            return Double(self.offset.x + temp)
        }
    }
}
