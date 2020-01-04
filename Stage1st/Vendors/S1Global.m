//
//  S1GlobalVariables.m
//  Stage1st
//
//  Created by hanza on 14-1-26.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import "S1Global.h"

@implementation S1Formatter

- (instancetype)init {
    self = [super init];
    if (self) {
        _dateCache = [[NSMutableDictionary alloc] init];
    }
    return self;
}
+ (S1Formatter *)sharedInstance
{
    static S1Formatter *myGlobalFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        myGlobalFormatter = [[S1Formatter alloc] init];
    });
    return myGlobalFormatter;
}

- (void)clearCache {
    _dateCache = [[NSMutableDictionary alloc] init];
}

- (NSDateFormatter *)dateFormatter {
    if (_dateFormatter == nil) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:NSLocalizedString(@"TopicListViewController.ListHeader_Style", @"Header Style")];
    }
    return _dateFormatter;
}

- (NSString *)headerForDate:(NSDate *)date {
    return [self.dateFormatter stringFromDate:date];
}

- (NSComparisonResult)compareDateString:(NSString *)dateString1 withDateString:(NSString *)dateString2 {
    NSDate *date1 = [self.dateCache valueForKey:dateString1];
    if (date1 == nil) {
        date1 = [self.dateFormatter dateFromString:dateString1];
        [self.dateCache setValue:date1 forKey:dateString1];
    }
    NSDate *date2 = [self.dateCache valueForKey:dateString2];
    if (date2 == nil) {
        date2 = [self.dateFormatter dateFromString:dateString2];
        [self.dateCache setValue:date2 forKey:dateString2];
    }
    if (date1 && date2) {
        return [date2 compare:date1];
    }
    return [dateString1 compare:dateString2];
}

@end


@implementation S1Global

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size
{
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, (CGRect){.size = size});
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage *)imageWithColor:(UIColor *)color
{
    return [self imageWithColor:color size:CGSizeMake(1, 1)];
}

// Assumes input like "#00FF00" (Green Color) or "#AA000000" (Black Color With Alpha 0.67)(#(AA)RRGGBB).
+ (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned int rgbValue = 0;

    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    if ( [hexString rangeOfString:@"#"].location == 0 ) {
        [scanner setScanLocation:1]; // bypass '#' character
    }
    [scanner scanHexInt:&rgbValue];
    if ([hexString length] > 7) {
        return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:((rgbValue & 0xFF000000) >> 24)/255.0];
    } else {
        return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
    }
}

+ (BOOL)regexMatchString:(NSString *)string withPattern:(NSString *)pattern {
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSInteger count = [[re matchesInString:string options:NSMatchingReportProgress range:NSMakeRange(0, string.length)] count];
    //DDLogDebug(@"REGEX Match: %ld", (long)count);
    return count != 0;
}
+ (NSArray *)regexExtractFromString:(NSString *)string withPattern:(NSString *)pattern andColums:(NSArray *)colums {
    if (string == nil) {
        return nil;
    }
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:string options:NSMatchingReportProgress range:NSMakeRange(0, string.length)];
    NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
    for (NSNumber *i in colums) {
        if ([i integerValue] < [result numberOfRanges]) {
            NSString *value = [string substringWithRange:[result rangeAtIndex:[i integerValue]]];
            [mutableArray addObject:value];
        }
        
    }
    //DDLogDebug(@"REGEX Extract: %@", mutableArray);
    return mutableArray;
}
+ (NSInteger)regexReplaceString:(NSMutableString *)mutableString matchPattern:(NSString *)pattern withTemplate:(NSString *)temp {
    NSError *error = nil;
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:&error];
    if (error) {
        DDLogError(@"Regex Replace error: %@ when initialize with pattern: %@", error, pattern);
        return 0;
    }
    return [re replaceMatchesInString:mutableString options:NSMatchingReportProgress range:NSMakeRange(0, [mutableString length]) withTemplate:temp];
}


@end
