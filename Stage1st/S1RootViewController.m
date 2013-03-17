//
//  S1RootViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1RootViewController.h"

#define _TRIGGER_THRESHOLD 60.0f

typedef enum {
    S1RootViewControllerStatusMasterViewDisplayed,
    S1RootViewControllerStatusDetailViewDisplayed
} S1RootViewControllerStatus;

typedef enum {
    DetailViewStatusInitial,
    DetailViewStatusTransformed
} DetailViewStatus;

@interface S1RootViewController ()

@property (nonatomic, strong) UIViewController *masterViewController;
@property (nonatomic, strong) UIViewController *detailViewController;

@property (nonatomic, strong) UIPanGestureRecognizer *panGR;

@end

@implementation S1RootViewController {
    S1RootViewControllerStatus _status;
    CGFloat _screenWidth;
}

- (id)initWithMasterViewController:(UIViewController *)controller
{
    self = [super init];
    if (!self) return nil;
    _masterViewController = controller;
    _status = S1RootViewControllerStatusMasterViewDisplayed;
    return self;
}

- (void)loadView
{
    UIView *containerView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _screenWidth = containerView.bounds.size.width;
    [self setView:containerView];
    [self addChildViewController:self.masterViewController];
    self.masterViewController.view.frame = self.view.bounds;
    [self.view addSubview:self.masterViewController.view];
    [self.masterViewController didMoveToParentViewController:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -

- (void)panned:(UIPanGestureRecognizer *)gestureRecognizer
{
    static DetailViewStatus detailViewStatus = DetailViewStatusInitial;
    CGPoint translation = [gestureRecognizer translationInView:self.detailViewController.view];
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        self.masterViewController.view.layer.shouldRasterize = YES;
        self.masterViewController.view.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        if (fabsf(translation.x) > fabsf(translation.y)) {
            if (translation.x > 0) {
                self.detailViewController.view.transform = CGAffineTransformMakeTranslation(translation.x, 0);
                self.masterViewController.view.transform = CGAffineTransformMakeTranslation(-_screenWidth/2 + translation.x/2, 0);
                detailViewStatus = DetailViewStatusTransformed;
            }
        }
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateChanged)
    {
        if (detailViewStatus == DetailViewStatusTransformed) {
            self.detailViewController.view.transform = CGAffineTransformMakeTranslation(translation.x > 0 ? translation.x : 0, 0);
            self.masterViewController.view.transform = CGAffineTransformMakeTranslation(translation.x > 0 ? -_screenWidth/2 +translation.x/2 : -_screenWidth, 0);
        }
        else
            [gestureRecognizer setTranslation:(CGPoint){0.0f, 0.0f} inView:self.detailViewController.view];
    }
    else {
        if (translation.x > _TRIGGER_THRESHOLD) {
            [self dismissDetailViewController];
        } else {
            [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.detailViewController.view.transform = CGAffineTransformIdentity;
                self.masterViewController.view.transform = CGAffineTransformMakeTranslation(-_screenWidth/2, 0);
            } completion:nil];
        }
        self.masterViewController.view.layer.shouldRasterize = NO;
        detailViewStatus = DetailViewStatusInitial;
    }
}

- (void)dismissDetailViewController
{
    [self.detailViewController willMoveToParentViewController:nil];
    [self.masterViewController viewWillAppear:NO];
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         CGRect endFrame = self.view.bounds;
                         endFrame.origin.x = endFrame.size.width;
                         self.detailViewController.view.frame = endFrame;
                         self.masterViewController.view.transform = CGAffineTransformIdentity;

                     }
                     completion:^(BOOL finished) {
                         [self.detailViewController.view removeGestureRecognizer:self.panGR];
                         [self.detailViewController.view removeFromSuperview];
                         [self.detailViewController removeFromParentViewController];
                         self.detailViewController = nil;
                         self.masterViewController.view.userInteractionEnabled = YES;
                         [self.masterViewController viewDidAppear:NO];
                         _status = S1RootViewControllerStatusMasterViewDisplayed;
                     }];
    
}

- (void)presentDetailViewController:(UIViewController *)controller
{
    self.detailViewController = controller;
    CGRect startFrame = self.view.bounds;
    startFrame.origin.x += startFrame.size.width;
    [self.detailViewController.view setFrame:startFrame];
    [self.detailViewController.view addGestureRecognizer:self.panGR];
    [self addShadowForView:self.detailViewController.view];
    [self addChildViewController:self.detailViewController];
    [self.view addSubview:self.detailViewController.view];
    [self.detailViewController didMoveToParentViewController:self];
    self.masterViewController.view.userInteractionEnabled = NO;
    [self.masterViewController viewWillDisappear:NO];
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.masterViewController.view.transform = CGAffineTransformMakeTranslation(-_screenWidth/2, 0.0);
                         CGRect endFrame = self.view.bounds;
                         self.detailViewController.view.frame = endFrame;
                     }
                     completion:^(BOOL finished) {
                         [self.masterViewController viewDidDisappear:NO];
                         _status = S1RootViewControllerStatusDetailViewDisplayed;
                     }];
}

- (BOOL)presentingDetailViewController
{
    return !(self.detailViewController == nil);
}

#pragma mark - Helpers

- (void)addShadowForView:(UIView *)view
{
    view.layer.shadowOpacity = 0.5;
    view.layer.shadowRadius = 5.0;
    view.layer.shadowOffset = CGSizeMake(-3.0, 0.0);
    view.layer.shadowPath = [[UIBezierPath bezierPathWithRoundedRect:self.detailViewController.view.bounds cornerRadius:3.0f] CGPath];
}

@end
