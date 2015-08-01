//
//  S1GlobalVariables.m
//  Stage1st
//
//  Created by hanza on 14-1-26.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import "S1Global.h"

@interface S1ColorManager ()

@property (nonatomic, strong) NSDictionary *palette;
@property (nonatomic, strong) NSDictionary *colorMap;

@end


@implementation S1ColorManager

+ (S1ColorManager *)sharedInstance
{
    static S1ColorManager *myGlobalHelper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        myGlobalHelper = [[S1ColorManager alloc] init];
    });
    return myGlobalHelper;
}

- init {
    self = [super init];
    if (self) {
        NSString *paletteName = [[NSUserDefaults standardUserDefaults] boolForKey:@"NightMode"] == YES ? @"DarkPalette" : @"DefaultPalette";
        NSString *path = [[NSBundle mainBundle] pathForResource:paletteName ofType:@"plist"];
        _palette = [NSDictionary dictionaryWithContentsOfFile:path];
        path = [[NSBundle mainBundle] pathForResource:@"ColorMap" ofType:@"plist"];
        _colorMap = [NSDictionary dictionaryWithContentsOfFile:path];
    }
    return self;
}

- (void)setPaletteForNightMode:(BOOL)nightMode {
    NSString *paletteName = nightMode == YES ? @"DarkPalette" : @"DefaultPalette";
    [self loadPaletteByName:paletteName andPushNotification:YES];
}

- (void)loadPaletteByName:(NSString *)paletteName andPushNotification:(BOOL)shouldPush {
    NSString *path = [[NSBundle mainBundle] pathForResource:paletteName ofType:@"plist"];
    _palette = [NSDictionary dictionaryWithContentsOfFile:path];
    [self updateGlobalAppearance];
    if (shouldPush) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"PaletteDidChangeNotification" object:nil];
    }
}

- (NSString *)htmlColorStringWithID:(NSString *)paletteID {
    return [self.palette valueForKey:paletteID];
}

- (UIColor *)colorInPaletteWithID:(NSString *)paletteID {
    NSString *colorString = [self.palette valueForKey:paletteID];
    if (colorString != nil) {
        UIColor *color = [S1Global colorFromHexString:colorString];
        if (color != nil) {
            return color;
        }
    }
    return [UIColor colorWithWhite:0 alpha:1];
}

- (UIColor *)colorForKey:(NSString *)key {
    NSString *paletteID = [self.colorMap valueForKey:key];
    if (paletteID == nil) {
        paletteID = @"default";
    }
    UIColor *color = [self colorInPaletteWithID:paletteID];
    return color;
}

- (BOOL)isDarkTheme {
    return [[self.palette valueForKey:@"Dark"] boolValue];
}

- (void)updateGlobalAppearance {
    [[UIToolbar appearance] setBarTintColor:[self colorForKey:@"appearance.toolbar.bartint"]];
    [[UIToolbar appearance] setTintColor:[self  colorForKey:@"appearance.toolbar.tint"]];
    [[UINavigationBar appearance] setBarTintColor:[self  colorForKey:@"appearance.navigationbar.battint"]];
    [[UINavigationBar appearance] setTintColor:[self  colorForKey:@"appearance.navigationbar.tint"]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName: [self colorForKey:@"appearance.navigationbar.title"],
                                                           NSFontAttributeName:[UIFont boldSystemFontOfSize:17.0],}];
    [[UISwitch appearance] setOnTintColor:[self  colorForKey:@"appearance.switch.tint"]];
    [[UITextField appearanceWhenContainedIn:[UISearchBar class], nil] setDefaultTextAttributes:@{NSForegroundColorAttributeName:[self colorForKey:@"appearance.searchbar.text"],
                                                                                                 NSFontAttributeName:[UIFont systemFontOfSize:14.0]}];
    [[UIScrollView appearance] setIndicatorStyle:[self isDarkTheme] ? UIScrollViewIndicatorStyleWhite: UIScrollViewIndicatorStyleDefault];
    [[UITextField appearance] setKeyboardAppearance:[self isDarkTheme] ? UIKeyboardAppearanceDark:UIKeyboardAppearanceDefault];
    if ([self isDarkTheme]) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    } else {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    }
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
    //NSLog(@"REGEX Match: %ld", (long)count);
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
    //NSLog(@"REGEX Extract: %@", mutableArray);
    return mutableArray;
}
+ (NSInteger)regexReplaceString:(NSMutableString *)mutableString matchPattern:(NSString *)pattern withTemplate:(NSString *)temp {
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    return [re replaceMatchesInString:mutableString options:NSMatchingReportProgress range:NSMakeRange(0, [mutableString length]) withTemplate:temp];
}


@end
