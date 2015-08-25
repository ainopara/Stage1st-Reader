//
//  NavigationControllerDelegate.m
//  Stage1st
//
//  Created by Zheng Li on 11/16/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "NavigationControllerDelegate.h"
#import "S1PopAnimator.h"
#import "S1PushAnimator.h"

#define _TRIGGER_THRESHOLD 60.0f
#define _TRIGGER_VELOCITY_THRESHOLD 500.0f

@interface NavigationControllerDelegate ()

@property (weak, nonatomic) IBOutlet UINavigationController *navigationController;
@property (strong, nonatomic) NSObject <UIViewControllerAnimatedTransitioning> *popAnimator;
@property (strong, nonatomic) NSObject <UIViewControllerAnimatedTransitioning> *pushAnimator;
@property (strong, nonatomic) UIPercentDrivenInteractiveTransition *interactionController;


@end


@implementation NavigationControllerDelegate

- (void)awakeFromNib
{
    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self.navigationController.view addGestureRecognizer:self.panRecognizer];
    
    self.popAnimator = [S1PopAnimator new];
    self.pushAnimator = [S1PushAnimator new];
}

- (void)pan:(UIPanGestureRecognizer*)recognizer
{
    UIView* view = self.navigationController.view;
    CGPoint translation = [recognizer translationInView:view];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.interactionController = [UIPercentDrivenInteractiveTransition new];
        self.interactionController.completionCurve = UIViewAnimationCurveLinear;
        [self.navigationController popViewControllerAnimated:YES];
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        [self.interactionController updateInteractiveTransition:translation.x > 0 ? translation.x / screenWidth : 0];
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        CGFloat velocityX = [recognizer velocityInView:view].x;
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        if ((translation.x > _TRIGGER_THRESHOLD || velocityX > _TRIGGER_VELOCITY_THRESHOLD) && velocityX >= -100) {
            self.interactionController.completionSpeed = 0.3 / fmin((screenWidth - fmin(translation.x, 0)) / fabs(velocityX), 0.3);
            //NSLog(@"Finish Speed: %f", self.interactionController.completionSpeed);
            [self.interactionController finishInteractiveTransition];
            if (self.navigationController.viewControllers.count == 1) {
                self.panRecognizer.enabled = NO;
            }
        } else {
            self.interactionController.completionSpeed = 0.3 / fmin(fabs(translation.x / velocityX), 0.3);
            //NSLog(@"Cancel Speed: %f", self.interactionController.completionSpeed);
            [self.interactionController cancelInteractiveTransition];
        }
        self.interactionController = nil;
    } else {
        //NSLog(@"Other Interaction Event:%d", recognizer.state);
        [self.interactionController cancelInteractiveTransition];
        self.interactionController = nil;
    }
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    if (operation == UINavigationControllerOperationPop) {
        return self.popAnimator;
    } else if (operation == UINavigationControllerOperationPush) {
        if (self.navigationController.viewControllers.count > 1) {
            self.panRecognizer.enabled = YES;
        }
        return self.pushAnimator;
    }
    return nil;
}

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController
{
    return self.interactionController;
}

- (UIInterfaceOrientationMask)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ForcePortraitForPhone"]) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            return UIInterfaceOrientationMaskPortrait;
        }
    }
    return UIInterfaceOrientationMaskAll;
}

@end
