//
//  UIScrollView+WKWebViewHack.h
//  Stage1st
//
//  Created by Zheng Li on 10/6/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIScrollView (S1Inspect)

@property (nonatomic, assign) BOOL s1_ignoringContentOffsetChange;

@end
