//
//  UIScrollView+WKWebViewHack.m
//  Stage1st
//
//  Created by Zheng Li on 10/6/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>
#import "UIScrollView+WKWebViewHack.h"

@implementation UIScrollView (S1Inspect)

+ (void)load {
    Method origin = class_getInstanceMethod([self class], @selector(setContentOffset:));
    Method newMethod = class_getInstanceMethod([self class], @selector(s1_setContentOffset:));
    method_exchangeImplementations(origin, newMethod);
}

- (void)s1_setContentOffset:(CGPoint)contentOffset {
#ifdef DEBUG
    if ([self isKindOfClass:NSClassFromString(@"WKScrollView")]) {
//        NSLog(@"%@ \n y: %f -> %f", self, self.contentOffset.y, contentOffset.y);
    }
#endif
    if ([self isKindOfClass:NSClassFromString(@"WKScrollView")]) {
        if (![self s1_ignoringContentOffsetChange]) {
            [self s1_setContentOffset:contentOffset];
        } else {
#ifdef DEBUG
            DDLogInfo(@"ignore change y: %f -> %f", self.contentOffset.y, contentOffset.y);
#endif
        }
    } else {
        [self s1_setContentOffset:contentOffset];
    }
}

- (void)setS1_ignoringContentOffsetChange:(BOOL)s1_ignoringContentOffsetChange {
    objc_setAssociatedObject(self, @selector(s1_ignoringContentOffsetChange), @(s1_ignoringContentOffsetChange), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)s1_ignoringContentOffsetChange {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number == nil) {
        return NO; // default to false
    }

    return [number boolValue];
}

- (void)setS1_trackingPageBottom:(BOOL)s1_trackingPageBottom {
    objc_setAssociatedObject(self, @selector(s1_trackingPageBottom), @(s1_trackingPageBottom), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)s1_trackingPageBottom {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number == nil) {
        return NO; // default to false
    }

    return [number boolValue];
}

@end
