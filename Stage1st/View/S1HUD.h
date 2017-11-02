//
//  S1HUD.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/23/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface S1HUD : UIView

@property (nonatomic, copy, readonly) NSString *text;
@property (nonatomic, copy) void (^refreshEventHandler)(S1HUD *aHUD);

- (void)show;
- (void)hideWithDelay:(NSTimeInterval)delay;

- (void)showActivityIndicator;
- (void)showRefreshButton;
- (void)showMessage:(NSString *)message;

@end
