//
//  S1HUD.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/23/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface S1HUD : UIView

+ (S1HUD *)showHUDInView:(UIView *)view;

- (void)hideWithDelay:(NSTimeInterval)delay;

@end
