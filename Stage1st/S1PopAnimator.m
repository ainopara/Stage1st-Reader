//
//  S1Animator.m
//  Stage1st
//
//  Created by Zheng Li on 11/16/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1PopAnimator.h"

@implementation S1PopAnimator

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    return 0.24;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    [[transitionContext containerView] insertSubview:toViewController.view belowSubview:fromViewController.view];
    
    fromViewController.view.layer.shadowOpacity = 0.5;
    fromViewController.view.layer.shadowRadius = 5.0;
    fromViewController.view.layer.shadowOffset = CGSizeMake(-3.0, 0.0);
    fromViewController.view.layer.shadowPath = [[UIBezierPath bezierPathWithRoundedRect:fromViewController.view.bounds cornerRadius:3.0f] CGPath];
    
    toViewController.view.transform = CGAffineTransformMakeTranslation(-screenWidth/2, 0);
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext] delay: 0.0 options: UIViewAnimationOptionCurveLinear animations:^{
        fromViewController.view.transform = CGAffineTransformMakeTranslation(screenWidth, 0);
        toViewController.view.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        NSLog(@"finished: %d,canceled: %d",finished, [transitionContext transitionWasCancelled]);
        fromViewController.view.transform = CGAffineTransformIdentity;
        toViewController.view.transform = CGAffineTransformIdentity;
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

@end
