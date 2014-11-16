//
//  NavigationControllerDelegate.m
//  Stage1st
//
//  Created by Zheng Li on 11/16/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "NavigationControllerDelegate.h"
#import "S1Animator.h"

@interface NavigationControllerDelegate ()

@property (weak, nonatomic) IBOutlet UINavigationController *navigationController;
@property (strong, nonatomic) S1Animator* animator;
@property (strong, nonatomic) UIPercentDrivenInteractiveTransition* interactionController;

@end


@implementation NavigationControllerDelegate

- (void)awakeFromNib
{
    UIPanGestureRecognizer* panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self.navigationController.view addGestureRecognizer:panRecognizer];
    
    self.animator = [S1Animator new];
}

- (void)pan:(UIPanGestureRecognizer*)recognizer
{
    UIView* view = self.navigationController.view;
    CGPoint translation = [recognizer translationInView:view];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        NSLog(@"Begin");
        // self.masterViewController.view.layer.shouldRasterize = YES;
        // self.masterViewController.view.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        if (fabsf(translation.x) > fabsf(translation.y)) {
            if (translation.x > 0 && self.navigationController.viewControllers.count > 1) {
                //self.detailViewController.view.transform = CGAffineTransformMakeTranslation(translation.x, 0);
                //self.masterViewController.view.transform = CGAffineTransformMakeTranslation(-_screenWidth/2 + translation.x/2, 0);
                //detailViewStatus = DetailViewStatusTransformed;
                self.interactionController = [UIPercentDrivenInteractiveTransition new];
                [self.navigationController popViewControllerAnimated:YES];
            }
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged)
    {
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        [self.interactionController updateInteractiveTransition:translation.x > 0 ? translation.x / screenWidth : 0];
        NSLog(@"Changed：%f", translation.x / screenWidth);
        //self.detailViewController.view.transform = CGAffineTransformMakeTranslation(translation.x > 0 ? translation.x : 0, 0);
        //self.masterViewController.view.transform = CGAffineTransformMakeTranslation(translation.x > 0 ? -_screenWidth/2 +translation.x/2 : -_screenWidth, 0);
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        /*
        CGFloat velocityX = [recognizer velocityInView:self.detailViewController.view].x;
        
        NSLog(@"%f, %f",translation.x, velocityX);
        if ((translation.x > _TRIGGER_THRESHOLD || velocityX > _TRIGGER_VELOCITY_THRESHOLD) && velocityX > 0) {
            [self dismissDetailViewController:fmin((_screenWidth - translation.x) / fabsf(velocityX), 0.3)];
        } else {
            [UIView animateWithDuration:fmin((translation.x / fabsf(velocityX)), 0.4) delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.detailViewController.view.transform = CGAffineTransformIdentity;
                self.masterViewController.view.transform = CGAffineTransformMakeTranslation(-_screenWidth/2, 0);
            } completion:nil];
        }
        self.masterViewController.view.layer.shouldRasterize = NO;
        */
        NSLog(@"End");
        if ([recognizer velocityInView:view].x > 0) {
            
            [self.interactionController finishInteractiveTransition];
            
        } else {
            [self.interactionController cancelInteractiveTransition];
        }
        //self.interactionController = nil;
    }
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    if (operation == UINavigationControllerOperationPop) {
        return self.animator;
    }
    return nil;
}

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController
{
    return self.interactionController;
}

@end
