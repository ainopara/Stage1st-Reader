//
//  NavigationControllerDelegate.h
//  Stage1st
//
//  Created by Zheng Li on 11/16/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class S1NavigationViewController;

NS_ASSUME_NONNULL_BEGIN

@interface NavigationControllerDelegate : NSObject <UINavigationControllerDelegate>

@property (weak, nonatomic, nullable) S1NavigationViewController *navigationController;

@property (strong, nonatomic) UIPanGestureRecognizer *panRecognizer;
@property (strong, nonatomic, nullable) UIPanGestureRecognizer *colorPanRecognizer;

- (instancetype)initWithNavigationController:(S1NavigationViewController *)navigationController;

@end

NS_ASSUME_NONNULL_END
