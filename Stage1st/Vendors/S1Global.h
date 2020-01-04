//
//  S1GlobalVariables.h
//  Stage1st
//
//  Created by hanza on 14-1-26.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h> 

#define IS_IPAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

@interface S1Formatter : NSObject

+ (S1Formatter *)sharedInstance;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSMutableDictionary *dateCache;

- (void)clearCache;
- (NSString *)headerForDate:(NSDate *)date;
- (NSComparisonResult)compareDateString:(NSString *)dateString1 withDateString:(NSString *)dateString2;

@end

// TODO: some method in this should be extension style.
@interface S1Global : NSObject

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
+ (UIImage *)imageWithColor:(UIColor *)color;

+ (UIColor *)colorFromHexString:(NSString *)hexString;

//Regex wrapper
+ (BOOL)regexMatchString:(NSString *)string withPattern:(NSString *)pattern;
+ (NSArray<NSString *> *)regexExtractFromString:(NSString *)string withPattern:(NSString *)pattern andColums:(NSArray<NSNumber *> *)colums;
+ (NSInteger)regexReplaceString:(NSMutableString *)string matchPattern:(NSString *)pattern withTemplate:(NSString *)temp;

@end
