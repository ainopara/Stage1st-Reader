//
//  APPullToActionController.swift
//  Stage1st
//
//  Created by Zheng Li on 6/22/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

import UIKit
import CocoaLumberjack

@objc public protocol PullToActionDelagete {
    optional func scrollViewDidEndDraggingOutsideTopBoundWithOffset(offset: CGFloat)
    optional func scrollViewDidEndDraggingOutsideBottomBoundWithOffset(offset: CGFloat)
    optional func scrollViewContentSizeDidChange(contentSize: CGSize)
    optional func scrollViewContentOffsetProgress(progress: [String: Double])
}

@objc public enum OffsetBaseLine: Int {
    case Top, Bottom, Left, Right
}

struct OffsetRange {
    let beginPosition: Double
    let endPosition: Double
    let baseLine: OffsetBaseLine

    func progress (offset: Double) -> Double {
        return (offset - beginPosition) / (endPosition - beginPosition)
    }
}

public class PullToActionController: NSObject, UIScrollViewDelegate {
    weak var scrollView: UIScrollView?
    weak var delegate: PullToActionDelagete?

    var offset: CGPoint = CGPoint(x: 0, y: 0)
    var size: CGSize = CGSize(width: 0, height: 0)
    var inset: UIEdgeInsets = UIEdgeInsetsZero
    private var progressAction: [String: OffsetRange] = Dictionary<String, OffsetRange>()

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        super.init()

        scrollView.delegate = self
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: .New, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentSize", options: .New, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentInset", options: .New, context: nil)
    }

    deinit {
        self.scrollView?.removeObserver(self, forKeyPath: "contentOffset")
        self.scrollView?.removeObserver(self, forKeyPath: "contentSize")
        self.scrollView?.removeObserver(self, forKeyPath: "contentInset")
        self.scrollView?.delegate = nil
        DDLogDebug("[PullToAction] Scroll View delegate set nil")
    }

    public func addConfigurationWithName(name: String, baseLine: OffsetBaseLine, beginPosition: Double, endPosition: Double) {
        progressAction.updateValue(OffsetRange(beginPosition: beginPosition, endPosition: endPosition, baseLine: baseLine), forKey: name)
    }

    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "contentOffset" {
            if let changes = change {
                self.offset = changes["new"]?.CGPointValue ?? self.offset
                if let delegateFunction = self.delegate?.scrollViewContentOffsetProgress {
                    var progress: [String: Double] = Dictionary<String, Double>()
                    for (name, actionOffset) in self.progressAction {
                        let progressValue = actionOffset.progress(self.baseLineOffset(actionOffset.baseLine))
                        progress.updateValue(progressValue, forKey: name)
                    }
                    delegateFunction(progress)
                }
            }
            //println("contentOffset: \(self.offset)")
        }
        if keyPath == "contentSize" {
            if let changes = change {
                self.size = changes["new"]?.CGSizeValue() ?? self.size
                //println("size:w: \(self.size.width) h:\(self.size.height)")
                self.delegate?.scrollViewContentSizeDidChange?(self.size)
            }
        }
        if keyPath == "contentInset" {
            if let changes = change {
                self.inset = changes["new"]?.UIEdgeInsetsValue() ?? self.inset
                //println("inset: top: \(self.inset.top) bottom: \(self.inset.bottom)")
            }
        }
    }

    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if self.offset.y < 0 {
            DDLogDebug("[PullToAction] End dragging <- \(self.offset.y)")
            self.delegate?.scrollViewDidEndDraggingOutsideTopBoundWithOffset?(self.offset.y)
            return
        }
        let bottomOffset = self.offset.y + scrollView.bounds.height - self.size.height //TODO: consider content inset
        if bottomOffset > 0 {
            DDLogDebug("[PullToAction] End dragging -> \(bottomOffset)")
            self.delegate?.scrollViewDidEndDraggingOutsideBottomBoundWithOffset?(bottomOffset)
            return
        }
    }

    private func baseLineOffset(baseLine: OffsetBaseLine) -> Double {
        guard let scrollView = self.scrollView else {
            return Double(0)
        }
        switch baseLine {
        case .Top:
            return Double(self.offset.y)
        case .Bottom:
            var temp = scrollView.bounds.height - self.size.height
            if temp > 0 { temp = 0 }
            return Double(self.offset.y + temp)
        case .Left:
            return Double(self.offset.x)
        case .Right:
            var temp = scrollView.bounds.width - self.size.width
            if temp > 0 { temp = 0 }
            return Double(self.offset.x + temp)
        }
    }
}
