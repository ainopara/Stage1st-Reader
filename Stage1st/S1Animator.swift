//
//  S1Animator.swift
//  Stage1st
//
//  Created by Zheng Li on 5/14/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

@objc enum TransitionDirection: Int {
    case push
    case pop
}

class S1Animator: NSObject, UIViewControllerAnimatedTransitioning {
    let direction: TransitionDirection

    init(direction: TransitionDirection) {
        self.direction = direction
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to),
            let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) else {
                assert(false)
                return
        }

        let containerView = transitionContext.containerView
        // TODO: remove this workaround once it is no more necessary
        toViewController.view.frame = containerView.bounds

        // FIXME: will take no effect if toViewController clipsToBounds == true, maybe add the effect to a temp view
        toViewController.view.layer.shadowOpacity = 0.5
        toViewController.view.layer.shadowRadius = 5.0
        toViewController.view.layer.shadowOffset = CGSize(width: -3.0, height: 0.0)
        toViewController.view.layer.shadowPath = UIBezierPath(rect: toViewController.view.bounds).cgPath

        let containerViewWidth = containerView.frame.width
        switch self.direction {
        case .push:
            containerView.insertSubview(toViewController.view, aboveSubview: fromViewController.view)
            fromViewController.view.transform = CGAffineTransform.identity
            toViewController.view.transform = CGAffineTransform(translationX: containerViewWidth, y: 0.0)
        case .pop:
            containerView.insertSubview(toViewController.view, belowSubview: fromViewController.view)
            fromViewController.view.transform = CGAffineTransform.identity
            toViewController.view.transform = CGAffineTransform(translationX: -containerViewWidth / 2.0, y: 0.0)
        }

        UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0.0, options: .curveLinear, animations: {
            switch self.direction {
            case .push:
                fromViewController.view.transform = CGAffineTransform(translationX: -containerViewWidth / 2.0, y: 0.0)
                toViewController.view.transform = CGAffineTransform.identity
            case .pop:
                fromViewController.view.transform = CGAffineTransform(translationX: containerViewWidth, y: 0.0)
                toViewController.view.transform = CGAffineTransform.identity
            }
        }) { (finished) in
            fromViewController.view.transform = CGAffineTransform.identity
            toViewController.view.transform = CGAffineTransform.identity
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
