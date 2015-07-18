//
//  S1GlobalVariables.h
//  Stage1st
//
//  Created by hanza on 14-1-26.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h> 

#define IS_RETINA ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] && ([UIScreen mainScreen].scale == 2.0))
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

@interface S1Global : NSObject
+ (S1Global *)sharedInstance;

- (UIColor *)color1;
- (UIColor *)color2;
- (UIColor *)color3;
- (UIColor *)color4;
- (UIColor *)color5;
- (UIColor *)color6;
- (UIColor *)color7;
- (UIColor *)color8;
- (UIColor *)color9;
- (UIColor *)color10;
- (UIColor *)color11;
- (UIColor *)color12;
- (UIColor *)color13;
- (UIColor *)color14;
- (UIColor *)color15;
- (UIColor *)color16;
- (UIColor *)color17;
- (UIColor *)color18;
- (UIColor *)color19;
- (UIColor *)color20;
- (UIColor *)color21;
- (UIColor *)color22;
- (UIColor *)color23;
- (UIColor *)color24;
- (UIColor *)color25;

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
+ (UIImage *)imageWithColor:(UIColor *)color;

+ (UIColor *)colorFromHexString:(NSString *)hexString;

+ (NSNumber *)HistoryLimitString2Number:(NSString *)stringKey;
+ (NSString *)HistoryLimitNumber2String:(NSNumber *)numberKey;

//Regex wrapper
+ (BOOL)regexMatchString:(NSString *)string withPattern:(NSString *)pattern;
+ (NSArray *)regexExtractFromString:(NSString *)string withPattern:(NSString *)pattern andColums:(NSArray *)colums;
+ (NSInteger)regexReplaceString:(NSMutableString *)string matchPattern:(NSString *)pattern withTemplate:(NSString *)temp;

@end
