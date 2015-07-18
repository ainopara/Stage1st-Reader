//
//  S1GlobalVariables.m
//  Stage1st
//
//  Created by hanza on 14-1-26.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import "S1Global.h"

@interface S1Global ()

@property (nonatomic, strong) NSDictionary *palette;

@end


@implementation S1Global

+ (S1Global *)sharedInstance
{
    static S1Global *myGlobalHelper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        myGlobalHelper = [[S1Global alloc] init];
    });
    return myGlobalHelper;
}

- init {
    self = [super init];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"DefaultPalette" ofType:@"plist"];
    self.palette = [NSDictionary dictionaryWithContentsOfFile:path];
    return self;
}

- (UIColor *)colorInPaletteWithID:(NSString *)paletteID {
    NSString *colorString = [self.palette valueForKey:paletteID];
    UIColor *color = [S1Global colorFromHexString:colorString];
    if (color == nil) {
        color = [UIColor colorWithWhite:0 alpha:1];
    }
    return color;
}


- (UIColor *)color1{return [self colorInPaletteWithID:@"1"];}
- (UIColor *)color2{return [self colorInPaletteWithID:@"2"];}
- (UIColor *)color3{return [self colorInPaletteWithID:@"3"];}
- (UIColor *)color4{return [self colorInPaletteWithID:@"4"];}
- (UIColor *)color5{return [self colorInPaletteWithID:@"5"];}
- (UIColor *)color6{return [self colorInPaletteWithID:@"6"];}
- (UIColor *)color7{return [self colorInPaletteWithID:@"7"];}
- (UIColor *)color8{return [self colorInPaletteWithID:@"8"];}
- (UIColor *)color9{return [self colorInPaletteWithID:@"9"];}
- (UIColor *)color10{return [self colorInPaletteWithID:@"10"];}
- (UIColor *)color11{return [self colorInPaletteWithID:@"11"];}
- (UIColor *)color12{return [self colorInPaletteWithID:@"12"];}
- (UIColor *)color13{return [self colorInPaletteWithID:@"13"];}
- (UIColor *)color14{return [self colorInPaletteWithID:@"14"];}
- (UIColor *)color15{return [self colorInPaletteWithID:@"15"];}
- (UIColor *)color16{return [self colorInPaletteWithID:@"16"];}
- (UIColor *)color17{return [self colorInPaletteWithID:@"17"];}
- (UIColor *)color18{return [self colorInPaletteWithID:@"18"];}
- (UIColor *)color19{return [self colorInPaletteWithID:@"19"];}
- (UIColor *)color20{return [self colorInPaletteWithID:@"20"];}
- (UIColor *)color21{return [self colorInPaletteWithID:@"21"];}
- (UIColor *)color22{return [self colorInPaletteWithID:@"22"];}
- (UIColor *)color23{return [self colorInPaletteWithID:@"23"];}
- (UIColor *)color24{return [self colorInPaletteWithID:@"24"];}
- (UIColor *)color25{return [self colorInPaletteWithID:@"25"];}

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

// Assumes input like "#00FF00" (#RRGGBB).
+ (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    if ( [hexString rangeOfString:@"#"].location == 0 ) {
        [scanner setScanLocation:1]; // bypass '#' character
    }
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1 - ((rgbValue & 0xFF000000) >> 24)/255.0];
}

+ (NSNumber *)HistoryLimitString2Number:(NSString *)stringKey
{
    if([stringKey isEqualToString:NSLocalizedString(@"SettingView_HistoryLimit_3days",@"")]){
        return @259200;
    } else if([stringKey isEqualToString:NSLocalizedString(@"SettingView_HistoryLimit_1week",@"")]){
        return @604800;
    } else if([stringKey isEqualToString:NSLocalizedString(@"SettingView_HistoryLimit_2weeks",@"")]){
        return @1209600;
    } else if([stringKey isEqualToString:NSLocalizedString(@"SettingView_HistoryLimit_1month",@"")]){
        return @2592000;
    }
    return @-1;
}

+ (NSString *)HistoryLimitNumber2String:(NSNumber *)numberKey
{
    if ([numberKey isEqualToNumber:@259200]) {
        return NSLocalizedString(@"SettingView_HistoryLimit_3days",@"");
    } else if ([numberKey isEqualToNumber:@604800]) {
        return NSLocalizedString(@"SettingView_HistoryLimit_1week",@"");
    } else if ([numberKey isEqualToNumber:@1209600]) {
        return NSLocalizedString(@"SettingView_HistoryLimit_2weeks",@"");
    } else if ([numberKey isEqualToNumber:@2592000]) {
        return NSLocalizedString(@"SettingView_HistoryLimit_1month",@"");
    }
    return NSLocalizedString(@"SettingView_HistoryLimit_Forever",@"");
}

+ (BOOL)regexMatchString:(NSString *)string withPattern:(NSString *)pattern {
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSInteger count = [[re matchesInString:string options:NSMatchingReportProgress range:NSMakeRange(0, string.length)] count];
    NSLog(@"REGEX Match: %ld", (long)count);
    return count != 0;
}
+ (NSArray *)regexExtractFromString:(NSString *)string withPattern:(NSString *)pattern andColums:(NSArray *)colums {
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:string options:NSMatchingReportProgress range:NSMakeRange(0, string.length)];
    NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
    for (NSNumber *i in colums) {
        if ([i integerValue] < [result numberOfRanges]) {
            NSString *value = [string substringWithRange:[result rangeAtIndex:[i integerValue]]];
            [mutableArray addObject:value];
        }
        
    }
    NSLog(@"REGEX Extract: %@", mutableArray);
    return mutableArray;
}
+ (NSInteger)regexReplaceString:(NSMutableString *)mutableString matchPattern:(NSString *)pattern withTemplate:(NSString *)temp {
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    return [re replaceMatchesInString:mutableString options:NSMatchingReportProgress range:NSMakeRange(0, [mutableString length]) withTemplate:temp];
}


@end
