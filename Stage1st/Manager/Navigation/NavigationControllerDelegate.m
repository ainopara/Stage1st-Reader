//
//  NavigationControllerDelegate.m
//  Stage1st
//
//  Created by Zheng Li on 11/16/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "NavigationControllerDelegate.h"

#define _TRIGGER_THRESHOLD 60.0f
#define _TRIGGER_VELOCITY_THRESHOLD 500.0f
#define _COLOR_CHANGE_TRIGGER_THRESHOLD 100.0f

@interface NavigationControllerDelegate () <UIGestureRecognizerDelegate>

@property (strong, nonatomic) S1Animator *popAnimator;
@property (strong, nonatomic) S1Animator *pushAnimator;
@property (strong, nonatomic) UIPercentDrivenInteractiveTransition *interactionController;

@end

@implementation NavigationControllerDelegate

- (instancetype)initWithNavigationController:(S1NavigationViewController *)navigationController
{
    self = [super init];
    if (self != nil) {
        self.navigationController = navigationController;
        self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        self.panRecognizer.delegate = self;
        [self.navigationController.view addGestureRecognizer:self.panRecognizer];

        self.popAnimator = [[S1Animator alloc] initWithDirection:TransitionDirectionPop];
        self.pushAnimator = [[S1Animator alloc] initWithDirection:TransitionDirectionPush];
    }
    return self;
}

- (void)colorPan:(UIPanGestureRecognizer *)recognizer
{
    UIView *view = self.navigationController.view;
    CGPoint translation = [recognizer translationInView:view];
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        DDLogVerbose(@"[ColorPan] %f",translation.y);
        if (translation.y > _COLOR_CHANGE_TRIGGER_THRESHOLD && [[NSUserDefaults standardUserDefaults] boolForKey:@"NightMode"] == NO) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NightMode"];
            [[ColorManager shared] switchPalette:PaletteTypeNight];
            recognizer.enabled = NO;
            recognizer.enabled = YES;
        }
        if (translation.y < -_COLOR_CHANGE_TRIGGER_THRESHOLD && [[NSUserDefaults standardUserDefaults] boolForKey:@"NightMode"] == YES) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NightMode"];
            [[ColorManager shared] switchPalette:PaletteTypeDay];
            recognizer.enabled = NO;
            recognizer.enabled = YES;
        }
    }
}

- (void)pan:(UIPanGestureRecognizer*)recognizer
{
    UIView* view = self.navigationController.view;
    CGPoint translation = [recognizer translationInView:view];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.interactionController = [UIPercentDrivenInteractiveTransition new];
        self.interactionController.completionCurve = UIViewAnimationCurveLinear;
        self.popAnimator.curve = UIViewAnimationOptionCurveLinear;
        [self.navigationController popViewControllerAnimated:YES];
        DDLogVerbose(@"[NavPan] Begin.");
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGFloat windowWidth = UIApplication.sharedApplication.delegate.window.bounds.size.width;
        [self.interactionController updateInteractiveTransition:translation.x > 0 ? translation.x / windowWidth : 0];
        DDLogVerbose(@"[NavPan] Update: %f.", translation.x > 0 ? translation.x / windowWidth : 0);
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        CGFloat velocityX = [recognizer velocityInView:view].x;
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        if ((translation.x > _TRIGGER_THRESHOLD || velocityX > _TRIGGER_VELOCITY_THRESHOLD) && velocityX >= -100) {
            self.interactionController.completionSpeed = 0.3 / fmin((screenWidth - fmin(translation.x, 0)) / fabs(velocityX), 0.3);
            DDLogVerbose(@"[NavPan] Finish Speed: %f", self.interactionController.completionSpeed);
            [self.interactionController finishInteractiveTransition];
            if (self.navigationController.viewControllers.count == 1) {
                self.panRecognizer.enabled = NO;
            }
        } else {
            self.interactionController.completionSpeed = 0.3 / fmin(fabs(translation.x / velocityX), 0.3);
            DDLogVerbose(@"[NavPan] Cancel Speed: %f", self.interactionController.completionSpeed);
            [self.interactionController cancelInteractiveTransition];
        }
        self.interactionController = nil;
        self.popAnimator.curve = UIViewAnimationOptionCurveEaseInOut;
    } else {
        DDLogError(@"[NavPan] Other Interaction Event:%ld", (long)recognizer.state);
        [self.interactionController cancelInteractiveTransition];
        self.interactionController = nil;
        self.popAnimator.curve = UIViewAnimationOptionCurveEaseInOut;
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == self.colorPanRecognizer) {
        if (gestureRecognizer.numberOfTouches == 1) {
            return NO;
        } else {
            return YES;
        }
    }

    if (gestureRecognizer == self.panRecognizer) {
        if (self.navigationController.viewControllers.count == 1) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == self.colorPanRecognizer) {
//        DDLogVerbose(@"pan gesture simultaneously with %@", otherGestureRecognizer);
//        if ([otherGestureRecognizer.view isKindOfClass:[NSClassFromString(@"WKScrollView") class]] && [otherGestureRecognizer isKindOfClass:[NSClassFromString(@"UIScrollViewPanGestureRecognizer") class]]) {
//            return YES;
//        }
    }

    return NO;
}

#pragma mark - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC
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

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                         interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController
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
