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
#define _COLOR_CHANGE_TRIGGER_THRESHOLD 100.0f

@interface NavigationControllerDelegate () <UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UINavigationController *navigationController;
@property (strong, nonatomic) NSObject <UIViewControllerAnimatedTransitioning> *popAnimator;
@property (strong, nonatomic) NSObject <UIViewControllerAnimatedTransitioning> *pushAnimator;
@property (strong, nonatomic) UIPercentDrivenInteractiveTransition *interactionController;


@end


@implementation NavigationControllerDelegate

- (void)awakeFromNib {
    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self.navigationController.view addGestureRecognizer:self.panRecognizer];
    self.colorPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(colorPan:)];
    self.colorPanRecognizer.delegate = self;
    [self.navigationController.view addGestureRecognizer:self.colorPanRecognizer];
    self.popAnimator = [S1PopAnimator new];
    self.pushAnimator = [S1PushAnimator new];
}



- (void)colorPan:(UIPanGestureRecognizer *)recognizer {
    UIView* view = self.navigationController.view;
    CGPoint translation = [recognizer translationInView:view];
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        DDLogVerbose(@"[ColorPan] %f",translation.y);
        if (translation.y > _COLOR_CHANGE_TRIGGER_THRESHOLD && [[NSUserDefaults standardUserDefaults] boolForKey:@"NightMode"] == NO) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NightMode"];
            [[APColorManager sharedInstance] switchPalette:PaletteTypeNight];
            recognizer.enabled = NO;
            recognizer.enabled = YES;
        }
        if (translation.y < -_COLOR_CHANGE_TRIGGER_THRESHOLD && [[NSUserDefaults standardUserDefaults] boolForKey:@"NightMode"] == YES) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NightMode"];
            [[APColorManager sharedInstance] switchPalette:PaletteTypeDay];
            recognizer.enabled = NO;
            recognizer.enabled = YES;
        }
    }
}

- (void)pan:(UIPanGestureRecognizer*)recognizer {
    UIView* view = self.navigationController.view;
    CGPoint translation = [recognizer translationInView:view];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.interactionController = [UIPercentDrivenInteractiveTransition new];
        self.interactionController.completionCurve = UIViewAnimationCurveLinear;
        [self.navigationController popViewControllerAnimated:YES];
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGRect screenRect = [[UIScreen mainScreen] applicationFrame];
        CGFloat screenWidth = screenRect.size.width;
        [self.interactionController updateInteractiveTransition:translation.x > 0 ? translation.x / screenWidth : 0];
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        CGFloat velocityX = [recognizer velocityInView:view].x;
        CGRect screenRect = [[UIScreen mainScreen] applicationFrame];
        CGFloat screenWidth = screenRect.size.width;
        if ((translation.x > _TRIGGER_THRESHOLD || velocityX > _TRIGGER_VELOCITY_THRESHOLD) && velocityX >= -100) {
            self.interactionController.completionSpeed = 0.3 / fmin((screenWidth - fmin(translation.x, 0)) / fabs(velocityX), 0.3);
            DDLogVerbose(@"Finish Speed: %f", self.interactionController.completionSpeed);
            [self.interactionController finishInteractiveTransition];
            if (self.navigationController.viewControllers.count == 1) {
                self.panRecognizer.enabled = NO;
            }
        } else {
            self.interactionController.completionSpeed = 0.3 / fmin(fabs(translation.x / velocityX), 0.3);
            DDLogVerbose(@"Cancel Speed: %f", self.interactionController.completionSpeed);
            [self.interactionController cancelInteractiveTransition];
        }
        self.interactionController = nil;
    } else {
        DDLogVerbose(@"Other Interaction Event:%ld", (long)recognizer.state);
        [self.interactionController cancelInteractiveTransition];
        self.interactionController = nil;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.colorPanRecognizer && gestureRecognizer.numberOfTouches == 1) {
        return NO;
    }
    return YES;
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

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    return self.interactionController;
}

- (UIInterfaceOrientationMask)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ForcePortraitForPhone"]) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            return UIInterfaceOrientationMaskPortrait;
        }
    }
    return UIInterfaceOrientationMaskAll;
}

@end
