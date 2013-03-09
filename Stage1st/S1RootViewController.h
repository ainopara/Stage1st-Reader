//
//  S1RootViewController.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface S1RootViewController : UIViewController

- (id)initWithMasterViewController:(UIViewController *)controller;

- (void)presentDetailViewController:(UIViewController *)controller;
- (void)dismissDetailViewController;

@end
