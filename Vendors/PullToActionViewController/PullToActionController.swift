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

    func progress(for offset: Double) -> Double {
        return (offset - beginPosition) / (endPosition - beginPosition)
    }
}

public class PullToActionController: NSObject {
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

    public func addConfiguration(withName name: String, baseLine: OffsetBaseLine, beginPosition: Double, endPosition: Double) {
        progressAction.updateValue(OffsetRange(beginPosition: beginPosition, endPosition: endPosition, baseLine: baseLine), forKey: name)
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            guard
                let changes = change,
                let newOffsetValue = changes[.newKey] as? NSValue else {
                return
            }

            self.offset = newOffsetValue.cgPointValue

            guard let delegateFunction = self.delegate?.scrollViewContentOffsetProgress else { return }
            var progress = [String: Double]()
            for (name, actionOffset) in self.progressAction {
                let progressValue = actionOffset.progress(for: self.currentOffset(relativeTo: actionOffset.baseLine))
                progress.updateValue(progressValue, forKey: name)
            }
            delegateFunction(progress)
//            DDLogVerbose("[PullToAction] contentOffset: \(self.offset)")
        }

        if keyPath == "contentSize" {
            guard
                let changes = change,
                let newSizeValue = changes[.newKey] as? NSValue else {
                return
            }

            let newSize = newSizeValue.cgSizeValue

            guard
//                (abs(self.size.width) < 0.1 && abs(self.size.height) < 0.1) ||
                abs(self.size.width - newSize.width) > 0.1 || abs(self.size.height - newSize.height) > 0.1 else {
                return
            }

            self.size = newSize

            DDLogVerbose("[PullToAction] contentSize:w: \(self.size.width) h:\(self.size.height)")
            self.delegate?.scrollViewContentSizeDidChange?(self.size)
        }

        if keyPath == "contentInset" {
            guard let changes = change, let newInsetValue = changes[.newKey] as? NSValue else { return }
            self.inset = newInsetValue.uiEdgeInsetsValue
            DDLogVerbose("[PullToAction] inset: top: \(self.inset.top) bottom: \(self.inset.bottom)")
        }
    }

    private func currentOffset(relativeTo baseLine: OffsetBaseLine) -> Double {
        guard let scrollView = self.scrollView else {
            return Double(0.0)
        }

        switch baseLine {
        case .top:
            return Double(self.offset.y)
        case .bottom:
            return Double(self.offset.y - max(self.size.height - scrollView.bounds.height, 0.0))
        case .left:
            return Double(self.offset.x)
        case .right:
            return Double(self.offset.x - max(self.size.width - scrollView.bounds.width, 0.0))
        }
    }
}

extension PullToActionController: UIScrollViewDelegate {
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        //TODO: consider content inset
        let topOffset = self.offset.y
        if topOffset < 0.0 {
            DDLogDebug("[PullToAction] End dragging <- \(topOffset)")
            self.delegate?.scrollViewDidEndDraggingOutsideTopBoundWithOffset?(topOffset)
            return
        }

        let bottomOffset = self.offset.y + scrollView.bounds.height - self.size.height
        if bottomOffset > 0.0 {
            DDLogDebug("[PullToAction] End dragging -> \(bottomOffset)")
            self.delegate?.scrollViewDidEndDraggingOutsideBottomBoundWithOffset?(bottomOffset)
            return
        }
    }

    // To disable pinch to zoom gesture in WKWebView
    open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }

    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
    }
}
