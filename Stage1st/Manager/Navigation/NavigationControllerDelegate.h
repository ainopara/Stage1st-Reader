//
//  NavigationControllerDelegate.h
//  Stage1st
//
//  Created by Zheng Li on 11/16/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RootNavigationViewController;

NS_ASSUME_NONNULL_BEGIN

@interface NavigationControllerDelegate : NSObject <UINavigationControllerDelegate>

@property (weak, nonatomic, nullable) RootNavigationViewController *navigationController;

@property (strong, nonatomic) UIPanGestureRecognizer *panRecognizer;
@property (strong, nonatomic, nullable) UIPanGestureRecognizer *colorPanRecognizer;

- (instancetype)initWithNavigationController:(RootNavigationViewController *)navigationController;

@end

NS_ASSUME_NONNULL_END
