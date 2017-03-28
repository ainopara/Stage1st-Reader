//
//  S1Animator.swift
//  Stage1st
//
//  Created by Zheng Li on 5/14/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import CocoaLumberjack

@objc enum TransitionDirection: Int {
    case push
    case pop
}

class S1Animator: NSObject, UIViewControllerAnimatedTransitioning {
    let direction: TransitionDirection
    var curve: UIViewAnimationOptions = .curveEaseInOut

    init(direction: TransitionDirection) {
        self.direction = direction
        super.init()
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
            let fromViewController = transitionContext.viewController(forKey: .from) else {
            assert(false)
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
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
        switch direction {
        case .push:
            containerView.insertSubview(toViewController.view, aboveSubview: fromViewController.view)
            fromViewController.view.transform = .identity
            toViewController.view.transform = CGAffineTransform(translationX: containerViewWidth, y: 0.0)
        case .pop:
            containerView.insertSubview(toViewController.view, belowSubview: fromViewController.view)
            fromViewController.view.transform = .identity
            toViewController.view.transform = CGAffineTransform(translationX: -containerViewWidth / 2.0, y: 0.0)
        }

        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, options: curve, animations: { [weak self] in
            guard let strongSelf = self else { return }
            switch strongSelf.direction {
            case .push:
                fromViewController.view.transform = CGAffineTransform(translationX: -containerViewWidth / 2.0, y: 0.0)
                toViewController.view.transform = .identity
            case .pop:
                fromViewController.view.transform = CGAffineTransform(translationX: containerViewWidth, y: 0.0)
                toViewController.view.transform = .identity
            }
        }) { finished in
            if MyAppDelegate.crashIssueTrackingModeEnabled {
                DDLogTracking("finshed: \(finished)")
                DDLogTracking("transitionWasCancelled: \(transitionContext.transitionWasCancelled)")
                DDLogTracking("containerView: \(transitionContext.containerView)")
                DDLogTracking("containerView.subviews: \(transitionContext.containerView.subviews)")
                DDLogTracking("fromViewController: \(String(describing: transitionContext.viewController(forKey: .from)))")
                DDLogTracking("toViewController: \(String(describing: transitionContext.viewController(forKey: .to)))")
            }
            fromViewController.view.transform = .identity
            toViewController.view.transform = .identity
            if MyAppDelegate.crashIssueTrackingModeEnabled {
                DDLogTracking("G")
            }
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            if MyAppDelegate.crashIssueTrackingModeEnabled {
                DDLogTracking("H")
            }
        }
    }
}

// MARK: -

protocol CardWithBlurredBackground {
    var backgroundBlurView: UIVisualEffectView { get }
    var containerView: UIView { get }
}

class S1ModalAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let presentType: PresentType
    enum PresentType {
        case present
        case dismissal
    }

    init(presentType: PresentType) {
        self.presentType = presentType
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        switch presentType {
        case .present:
            guard let toViewController = transitionContext.viewController(forKey: .to) else {
                assert(false)
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                return
            }

            let containerView = transitionContext.containerView

            guard let targetViewController = toViewController as? CardWithBlurredBackground else {
                assert(false)
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                return
            }

            let blurredBackgroundView = targetViewController.backgroundBlurView
            let contentView = targetViewController.containerView

            contentView.alpha = 0.0
            contentView.transform = CGAffineTransform.init(scaleX: 0.9, y: 0.9)
            containerView.addSubview(toViewController.view)
            UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
                blurredBackgroundView.effect = UIBlurEffect(style: .dark)
                contentView.alpha = 1.0
                contentView.transform = CGAffineTransform.identity
            }) { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        case .dismissal:
            guard let fromViewController = transitionContext.viewController(forKey: .from) else {
                assert(false)
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                return
            }

            guard let targetViewController = fromViewController as? CardWithBlurredBackground else {
                assert(false)
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                return
            }

            let blurredBackgroundView = targetViewController.backgroundBlurView
            let contentView = targetViewController.containerView

            UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
                contentView.alpha = 0.0
                contentView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                blurredBackgroundView.effect = nil
            }) { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
}
