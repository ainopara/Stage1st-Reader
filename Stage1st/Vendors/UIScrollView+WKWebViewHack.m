//
//  UIScrollView+WKWebViewHack.m
//  Stage1st
//
//  Created by Zheng Li on 10/6/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>
#import "UIScrollView+WKWebViewHack.h"
#import <objc/runtime.h>

@implementation UIScrollView (S1Inspect)

+ (void)load {
    Method origin = class_getInstanceMethod([self class], @selector(setContentOffset:));
    Method newMethod = class_getInstanceMethod([self class], @selector(s1_setContentOffset:));
    method_exchangeImplementations(origin, newMethod);
}

- (void)s1_setContentOffset:(CGPoint)contentOffset {
    if ([self isKindOfClass:NSClassFromString(@"WKScrollView")]) {
//        DDLogVerbose(@"WKScrollView<%p> offsetY: %f -> %f", self, self.contentOffset.y, contentOffset.y);
        if (![self s1_ignoringContentOffsetChangedToZero]) {
            [self s1_setContentOffset:contentOffset];
        } else {
            if (contentOffset.y != 0.0) {
                [self s1_setContentOffset:contentOffset];
            } else {
                DDLogWarn(@"WKScrollView<%p> ignore offsetY change: %f -> %f", self, self.contentOffset.y, contentOffset.y);
            }
        }
    } else {
        [self s1_setContentOffset:contentOffset];
    }
}

- (void)setS1_ignoringContentOffsetChangedToZero:(BOOL)s1_ignoringContentOffsetChangedToZero {
    objc_setAssociatedObject(self, @selector(s1_ignoringContentOffsetChangedToZero), @(s1_ignoringContentOffsetChangedToZero), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)s1_ignoringContentOffsetChangedToZero {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number == nil) {
        return NO; // default to false
    }

    return [number boolValue];
}

@end
