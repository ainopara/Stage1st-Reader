//
//  S1Animator.swift
//  Stage1st
//
//  Created by Zheng Li on 5/14/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

@objc enum TransitionDirection: Int {
    case Push
    case Pop
}

class S1Animator: NSObject, UIViewControllerAnimatedTransitioning {
    let direction: TransitionDirection

    init(direction: TransitionDirection) {
        self.direction = direction
        super.init()
    }

    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return 0.3
    }

    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        guard let
            toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey),
            fromViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey),
            containerView = transitionContext.containerView() else {
                assert(false)
                return
        }
        // TODO: remove this workaround once it is no more necessary
        toViewController.view.frame = containerView.bounds

        // FIXME: will take no effect if toViewController clipsToBounds == true, maybe add the effect to a temp view
        toViewController.view.layer.shadowOpacity = 0.5
        toViewController.view.layer.shadowRadius = 5.0
        toViewController.view.layer.shadowOffset = CGSize(width: -3.0, height: 0.0)
        toViewController.view.layer.shadowPath = UIBezierPath(rect: toViewController.view.bounds).CGPath

        let containerViewWidth = containerView.frame.width
        switch self.direction {
        case .Push:
            containerView.insertSubview(toViewController.view, aboveSubview: fromViewController.view)
            fromViewController.view.transform = CGAffineTransformIdentity
            toViewController.view.transform = CGAffineTransformMakeTranslation(containerViewWidth, 0.0)
        case .Pop:
            containerView.insertSubview(toViewController.view, belowSubview: fromViewController.view)
            fromViewController.view.transform = CGAffineTransformIdentity
            toViewController.view.transform = CGAffineTransformMakeTranslation(-containerViewWidth / 2.0, 0.0)
        }

        UIView.animateWithDuration(self.transitionDuration(transitionContext), delay: 0.0, options: .CurveLinear, animations: {
            switch self.direction {
            case .Push:
                fromViewController.view.transform = CGAffineTransformMakeTranslation(-containerViewWidth / 2.0, 0.0)
                toViewController.view.transform = CGAffineTransformIdentity
            case .Pop:
                fromViewController.view.transform = CGAffineTransformMakeTranslation(containerViewWidth, 0.0)
                toViewController.view.transform = CGAffineTransformIdentity
            }
        }) { (finished) in
            fromViewController.view.transform = CGAffineTransformIdentity
            toViewController.view.transform = CGAffineTransformIdentity
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
        }
    }
}
