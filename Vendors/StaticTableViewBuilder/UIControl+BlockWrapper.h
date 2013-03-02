//
//  UIControl+BlockWrapper.h
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 1/27/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIControl (BlockWrapper)

- (void)addEventHandler:(void (^)(id sender, UIEvent *event))handler
        forControlEvent:(UIControlEvents)controlEvent;

- (void)removeEventHandlerForControlEvent:(UIControlEvents)controlEvent;

@end
