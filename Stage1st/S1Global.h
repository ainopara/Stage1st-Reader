//
//  S1GlobalVariables.h
//  Stage1st
//
//  Created by hanza on 14-1-26.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

#define IS_RETINA ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] && ([UIScreen mainScreen].scale == 2.0))
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_WIDE_DEVICE ([UIScreen mainScreen].bounds.size.width > 400 && [UIScreen mainScreen].bounds.size.height > 400)

@interface S1Global : NSObject
+ (UIColor *)color1;
+ (UIColor *)color2;
+ (UIColor *)color3;
+ (UIColor *)color4;
+ (UIColor *)color5;
+ (UIColor *)color6;
+ (UIColor *)color7;
+ (UIColor *)color8;
+ (UIColor *)color9;
+ (UIColor *)color10;
+ (UIColor *)color11;
+ (UIColor *)color12;
+ (UIColor *)color13;
+ (UIColor *)color14;
+ (UIColor *)color15;
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
+ (UIImage *)imageWithColor:(UIColor *)color;

+ (NSNumber *)HistoryLimitString2Number:(NSString *)stringKey;
+ (NSString *)HistoryLimitNumber2String:(NSNumber *)numberKey;

//Regex wrapper
+ (BOOL)regexMatchString:(NSString *)string withPattern:(NSString *)pattern;
+ (NSArray *)regexExtractFromString:(NSString *)string withPattern:(NSString *)pattern andColums:(NSArray *)colums;
+ (NSInteger)regexReplaceString:(NSMutableString *)string matchPattern:(NSString *)pattern withTemplate:(NSString *)temp;

@end
