//
//  S1AppDelegate.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class S1AppDelegate;
@class NavigationControllerDelegate;
@class Reachability;

extern S1AppDelegate *MyAppDelegate;

@interface S1AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NavigationControllerDelegate *navigationDelegate;
@property (nonatomic, strong, readonly) Reachability *reachability;

@end
