//
//  S1HUD.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/23/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface S1HUD : UIView

@property (nonatomic, copy) NSString *text;

@property (nonatomic, copy) void (^refreshEventHandler)(S1HUD *aHUD);

+ (S1HUD *)showHUDInView:(UIView *)view;

- (void)showActivityIndicator;
- (void)showRefreshButton;

- (void)hideWithDelay:(NSTimeInterval)delay;

@end
