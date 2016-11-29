//
//  APPullToActionController.swift
//  Stage1st
//
//  Created by Zheng Li on 6/22/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

import CocoaLumberjack

public struct OffsetRange {
    public enum BaseLine: Int {
        case top, bottom, left, right
    }

    let beginPosition: Double
    let endPosition: Double
    let baseLine: BaseLine

    func progress(for currentOffset: Double) -> Double {
        return (currentOffset - beginPosition) / (endPosition - beginPosition)
    }
}

// MARK: -
public class PullToActionController: NSObject {
    weak var scrollView: UIScrollView? // ???: Should I make this strong?
    weak var delegate: PullToActionDelagete?

    var offset: CGPoint = .zero
    var size: CGSize = .zero
    var inset: UIEdgeInsets = .zero
    fileprivate var progressActions = Dictionary<String, OffsetRange>()

    // MARK: -
    init(scrollView: UIScrollView) {
        self.scrollView = scrollView

        super.init()

        scrollView.delegate = self // TODO: forward message to original delegate of the scroll view.
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentInset", options: .new, context: nil)
    }

    deinit {
        DDLogDebug("[PullToAction] deinit")
    }

    public func setConfiguration(withName name: String, baseLine: OffsetRange.BaseLine, beginPosition: Double, endPosition: Double) {
        progressActions.updateValue(OffsetRange(beginPosition: beginPosition, endPosition: endPosition, baseLine: baseLine), forKey: name)
    }

    public func stop() {
        scrollView?.removeObserver(self, forKeyPath: "contentOffset")
        scrollView?.removeObserver(self, forKeyPath: "contentSize")
        scrollView?.removeObserver(self, forKeyPath: "contentInset")
        scrollView?.delegate = nil
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            guard
                let changes = change,
                let newOffsetValue = changes[.newKey] as? NSValue else {
                return
            }

            offset = newOffsetValue.cgPointValue

            guard let delegateFunction = delegate?.scrollViewContentOffsetProgress else {
                return
            }

            var progress = [String: Double]()
            for (name, actionOffset) in progressActions {
                let progressValue = actionOffset.progress(for: currentOffset(relativeTo: actionOffset.baseLine))
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

            guard abs(size.width - newSize.width) > 0.1 || abs(size.height - newSize.height) > 0.1 else {
                return
            }

            size = newSize

            DDLogVerbose("[PullToAction] contentSize:w: \(size.width) h:\(size.height)")
            delegate?.scrollViewContentSizeDidChange?(size)
        }

        if keyPath == "contentInset" {
            guard
                let changes = change,
                let newInsetValue = changes[.newKey] as? NSValue else {
                return
            }

            inset = newInsetValue.uiEdgeInsetsValue
            DDLogVerbose("[PullToAction] inset: top: \(inset.top) bottom: \(inset.bottom)")
        }
    }

    private func currentOffset(relativeTo baseLine: OffsetRange.BaseLine) -> Double {
        guard let scrollView = self.scrollView else {
            return Double(0.0)
        }

        switch baseLine {
        case .top:
            return Double(offset.y)
        case .bottom:
            return Double(offset.y - max(size.height - scrollView.bounds.height, 0.0))
        case .left:
            return Double(offset.x)
        case .right:
            return Double(offset.x - max(size.width - scrollView.bounds.width, 0.0))
        }
    }
}

// MARK: UIScrollViewDelegate
extension PullToActionController: UIScrollViewDelegate {
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        //TODO: consider content inset
        let topOffset = offset.y
        if topOffset < 0.0 {
            DDLogDebug("[PullToAction] End dragging <- \(topOffset)")
            delegate?.scrollViewDidEndDraggingOutsideTopBound?(with: topOffset)
            return
        }

        let bottomOffset = offset.y + scrollView.bounds.height - size.height
        if bottomOffset > 0.0 {
            DDLogDebug("[PullToAction] End dragging -> \(bottomOffset)")
            delegate?.scrollViewDidEndDraggingOutsideBottomBound?(with: bottomOffset)
            return
        }
    }

    // To disable pinch to zoom gesture in WKWebView
    open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }

    // To fix bug in WKWebView
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
    }
}

// MARK: -
@objc public protocol PullToActionDelagete {
    @objc optional func scrollViewDidEndDraggingOutsideTopBound(with offset: CGFloat)
    @objc optional func scrollViewDidEndDraggingOutsideBottomBound(with offset: CGFloat)
    @objc optional func scrollViewContentSizeDidChange(_ contentSize: CGSize)
    @objc optional func scrollViewContentOffsetProgress(_ progress: [String: Double])
}
