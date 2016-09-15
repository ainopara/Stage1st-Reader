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
    @objc optional func scrollViewDidEndDraggingOutsideTopBoundWithOffset(_ offset: CGFloat)
    @objc optional func scrollViewDidEndDraggingOutsideBottomBoundWithOffset(_ offset: CGFloat)
    @objc optional func scrollViewContentSizeDidChange(_ contentSize: CGSize)
    @objc optional func scrollViewContentOffsetProgress(_ progress: [String: Double])
}

@objc public enum OffsetBaseLine: Int {
    case top, bottom, left, right
}

struct OffsetRange {
    let beginPosition: Double
    let endPosition: Double
    let baseLine: OffsetBaseLine

    func progress (_ offset: Double) -> Double {
        return (offset - beginPosition) / (endPosition - beginPosition)
    }
}

open class PullToActionController: NSObject, UIScrollViewDelegate {
    weak var scrollView: UIScrollView?
    weak var delegate: PullToActionDelagete?

    var offset: CGPoint = CGPoint(x: 0.0, y: 0.0)
    var size: CGSize = CGSize(width: 0.0, height: 0.0)
    var inset: UIEdgeInsets = UIEdgeInsets.zero
    fileprivate var progressAction: [String: OffsetRange] = Dictionary<String, OffsetRange>()

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        super.init()

        scrollView.delegate = self // TODO: forward message to original delegate of the scroll view.
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentInset", options: .new, context: nil)
    }

    deinit {
        self.scrollView?.removeObserver(self, forKeyPath: "contentOffset")
        self.scrollView?.removeObserver(self, forKeyPath: "contentSize")
        self.scrollView?.removeObserver(self, forKeyPath: "contentInset")
        self.scrollView?.delegate = nil

        DDLogDebug("[PullToAction] deinit")
    }

    open func addConfigurationWithName(_ name: String, baseLine: OffsetBaseLine, beginPosition: Double, endPosition: Double) {
        progressAction.updateValue(OffsetRange(beginPosition: beginPosition, endPosition: endPosition, baseLine: baseLine), forKey: name)
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            guard let changes = change, let newOffsetValue = changes[.newKey] as? NSValue else { return }
            self.offset = newOffsetValue.cgPointValue

            guard let delegateFunction = self.delegate?.scrollViewContentOffsetProgress else { return }
            var progress = [String: Double]()
            for (name, actionOffset) in self.progressAction {
                let progressValue = actionOffset.progress(self.baseLineOffset(actionOffset.baseLine))
                progress.updateValue(progressValue, forKey: name)
            }
            delegateFunction(progress)
//            DDLogVerbose("[PullToAction] contentOffset: \(self.offset)")
        }

        if keyPath == "contentSize" {
            guard let changes = change, let newSizeValue = changes[.newKey] as? NSValue else { return }
            self.size = newSizeValue.cgSizeValue
            DDLogVerbose("[PullToAction] contentSize:w: \(self.size.width) h:\(self.size.height)")
            self.delegate?.scrollViewContentSizeDidChange?(self.size)
        }

        if keyPath == "contentInset" {
            guard let changes = change, let newInsetValue = changes[.newKey] as? NSValue else { return }
            self.inset = newInsetValue.uiEdgeInsetsValue
            DDLogVerbose("[PullToAction] inset: top: \(self.inset.top) bottom: \(self.inset.bottom)")
        }
    }

    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if self.offset.y < 0.0 {
            DDLogDebug("[PullToAction] End dragging <- \(self.offset.y)")
            self.delegate?.scrollViewDidEndDraggingOutsideTopBoundWithOffset?(self.offset.y)
            return
        }
        let bottomOffset = self.offset.y + scrollView.bounds.height - self.size.height //TODO: consider content inset
        if bottomOffset > 0.0 {
            DDLogDebug("[PullToAction] End dragging -> \(bottomOffset)")
            self.delegate?.scrollViewDidEndDraggingOutsideBottomBoundWithOffset?(bottomOffset)
            return
        }
    }

    fileprivate func baseLineOffset(_ baseLine: OffsetBaseLine) -> Double {
        guard let scrollView = self.scrollView else { return Double(0.0) }
        switch baseLine {
        case .top:
            return Double(self.offset.y)
        case .bottom:
            var temp = scrollView.bounds.height - self.size.height
            if temp > 0.0 { temp = 0.0 }
            return Double(self.offset.y + temp)
        case .left:
            return Double(self.offset.x)
        case .right:
            var temp = scrollView.bounds.width - self.size.width
            if temp > 0.0 { temp = 0.0 }
            return Double(self.offset.x + temp)
        }
    }
}
