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

@interface S1ColorManager : NSObject

+ (S1ColorManager *)sharedInstance;

- (void)setPaletteForNightMode:(BOOL)nightMode;
- (void)loadPaletteByName:(NSString *)paletteName andPushNotification:(BOOL)shouldPush;
- (BOOL)isDarkTheme;
- (void)updateGlobalAppearance;

- (NSString *)htmlColorStringWithID:(NSString *)paletteID;
- (UIColor *)colorForKey:(NSString *)key;

@end


@interface S1Global : NSObject

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
