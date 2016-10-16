//
//  NavigationControllerDelegate.h
//  Stage1st
//
//  Created by Zheng Li on 11/16/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NavigationControllerDelegate : NSObject <UINavigationControllerDelegate>

@property (strong, nonatomic) UIScreenEdgePanGestureRecognizer *panRecognizer;
@property (strong, nonatomic) UIPanGestureRecognizer *colorPanRecognizer;

- (instancetype)initWithNavigationController:(UINavigationController *)navigationController;

@end
