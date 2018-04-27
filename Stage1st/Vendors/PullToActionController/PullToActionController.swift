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
    public private(set) var scrollView: UIScrollView?
    public weak var delegate: PullToActionDelagete?

    public private(set) var offset: CGPoint = .zero
    public private(set) var size: CGSize = .zero
    public private(set) var inset: UIEdgeInsets = .zero

    public var filterDuplicatedSizeEvent = false

    private var progressActions = [String: OffsetRange]()
    private var observations = [NSKeyValueObservation]()

    // MARK: -
    public init(scrollView: UIScrollView) {
        self.scrollView = scrollView

        super.init()

        scrollView.delegate = self

        let offsetObserver = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] (scrollView, change) in
            guard let strongSelf = self else { return }
            guard let offset = change.newValue else { return }

            strongSelf.offset = offset

            var reports = [String: Double]()
            for (name, actionOffset) in strongSelf.progressActions {
                let progressValue = actionOffset.progress(for: strongSelf.currentOffset(relativeTo: actionOffset.baseLine))
                reports[name] = progressValue
            }

//            S1LogVerbose("[PullToAction] contentOffset: \(self.offset)")
            if let delegateFunction = strongSelf.delegate?.scrollViewContentOffsetProgress {
                delegateFunction(reports)
            }
        }

        observations.append(offsetObserver)

        let sizeObserver = scrollView.observe(\.contentSize, options: [.new]) { [weak self] (scrollView, change) in
            guard let strongSelf = self else { return }
            guard let size = change.newValue else { return }

            let oldSize = strongSelf.size
            strongSelf.size = size

            if strongSelf.filterDuplicatedSizeEvent && abs(size.height - oldSize.height) < 0.01 && abs(size.width - oldSize.width) < 0.01 {
                return
            }

            S1LogVerbose("[PullToAction] contentSize:w: \(size.width) h:\(size.height)")
            if let delegateFunction = strongSelf.delegate?.scrollViewContentSizeDidChange {
                delegateFunction(size)
            }
        }

        observations.append(sizeObserver)

        let insetObserver = scrollView.observe(\.contentInset, options: [.new]) { [weak self] (scrollView, change) in
            guard let strongSelf = self else { return }
            guard let inset = change.newValue else { return }

            strongSelf.inset = inset

            S1LogVerbose("[PullToAction] inset: top: \(inset.top) bottom: \(inset.bottom)")
        }

        observations.append(insetObserver)
    }

    deinit {
        S1LogDebug("[PullToAction] deinit")
    }

    public func addObservation(withName name: String, baseLine: OffsetRange.BaseLine, beginPosition: Double, endPosition: Double) {
        progressActions[name] = OffsetRange(beginPosition: beginPosition, endPosition: endPosition, baseLine: baseLine)
    }

    public func removeObservation(withName name: String) {
        progressActions.removeValue(forKey: name)
    }

    public var observationNames: [String] {
        return Array(progressActions.keys)
    }

    public func stop() {
        for observation in observations {
            observation.invalidate()
        }
        observations.removeAll()
        scrollView?.delegate = nil
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

private let forwardingScrollViewDelegateMethods = [
    #selector(UIScrollViewDelegate.scrollViewDidScroll(_:)),
    #selector(UIScrollViewDelegate.scrollViewDidZoom(_:)),
    #selector(UIScrollViewDelegate.scrollViewWillBeginDragging(_:)),
    #selector(UIScrollViewDelegate.scrollViewWillEndDragging(_:withVelocity:targetContentOffset:)),
//    #selector(UIScrollViewDelegate.scrollViewDidEndDragging(_:willDecelerate:)), // Implimented by PullToActionController
    #selector(UIScrollViewDelegate.scrollViewWillBeginDecelerating(_:)),
    #selector(UIScrollViewDelegate.scrollViewDidEndDecelerating(_:)),
    #selector(UIScrollViewDelegate.scrollViewDidEndScrollingAnimation(_:)),
    #selector(UIScrollViewDelegate.viewForZooming(in:)),
    #selector(UIScrollViewDelegate.scrollViewWillBeginZooming(_:with:)),
    #selector(UIScrollViewDelegate.scrollViewDidEndZooming(_:with:atScale:)),
    #selector(UIScrollViewDelegate.scrollViewShouldScrollToTop(_:)),
    #selector(UIScrollViewDelegate.scrollViewDidScrollToTop(_:))
]

// MARK: UIScrollViewDelegate
extension PullToActionController: UIScrollViewDelegate {
    public override func responds(to aSelector: Selector!) -> Bool {
        for aForwardingScrollViewDelegateMethod in forwardingScrollViewDelegateMethods where aSelector == aForwardingScrollViewDelegateMethod {
            return delegate?.responds(to: aSelector) ?? false
        }

        return super.responds(to: aSelector)
    }

    public override func forwardingTarget(for aSelector: Selector!) -> Any? {
        for aForwardingScrollViewDelegateMethod in forwardingScrollViewDelegateMethods where aSelector == aForwardingScrollViewDelegateMethod {
            return delegate
        }

        return super.forwardingTarget(for: aSelector)
    }

    // MARK: -
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        //TODO: consider content inset
        let topOffset = offset.y
        if topOffset < 0.0 {
            S1LogDebug("[PullToAction] End dragging <- \(topOffset)")
            delegate?.scrollViewDidEndDraggingOutsideTopBound?(with: topOffset)
            return
        }

        let bottomOffset = offset.y + scrollView.bounds.height - size.height
        if bottomOffset > 0.0 {
            S1LogDebug("[PullToAction] End dragging -> \(bottomOffset)")
            delegate?.scrollViewDidEndDraggingOutsideBottomBound?(with: bottomOffset)
            return
        }
    }
}

// MARK: -
@objc public protocol PullToActionDelagete: UIScrollViewDelegate {
    @objc optional func scrollViewDidEndDraggingOutsideTopBound(with offset: CGFloat)
    @objc optional func scrollViewDidEndDraggingOutsideBottomBound(with offset: CGFloat)
    @objc optional func scrollViewContentSizeDidChange(_ contentSize: CGSize)
    @objc optional func scrollViewContentOffsetProgress(_ progress: [String: Double])
}
