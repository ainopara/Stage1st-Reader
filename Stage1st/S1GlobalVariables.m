//
//  S1GlobalVariables.m
//  Stage1st
//
//  Created by hanza on 14-1-26.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import "S1GlobalVariables.h"
//[S1GlobalVariables color]
@implementation S1GlobalVariables
+(UIColor *)color1{return [UIColor colorWithRed:0.822 green:0.853 blue:0.756 alpha:1.000];}
+(UIColor *)color2{return [UIColor colorWithRed:0.596 green:0.600 blue:0.516 alpha:1.000];}
+(UIColor *)color3{return [UIColor colorWithWhite:0.15 alpha:1.0];}
+(UIColor *)color4{return [UIColor colorWithRed:56.0f/255.0f green:84.0f/255.0f blue:135.0f/255.0f alpha:1.0f];}
+(UIColor *)color5{return [UIColor colorWithRed:0.96 green:0.97 blue:0.92 alpha:1.0];}
+(UIColor *)color6{return [UIColor colorWithWhite:0.20f alpha:1.0f];}
+(UIColor *)color7{return [UIColor colorWithRed:0.813 green:0.827 blue:0.726 alpha:1.000];}
+(UIColor *)color8{return [UIColor colorWithRed: 0.92 green: 0.92 blue: 0.86 alpha: 1];}
+(UIColor *)color9{return [UIColor colorWithRed:0.628 green:0.611 blue:0.484 alpha:1.000];}
+(UIColor *)color10{return [UIColor colorWithRed:0.744 green:0.776 blue:0.696 alpha:1.000];}
+(UIColor *)color11{return nil;}
+(UIColor *)color12{return nil;}
+(UIColor *)color13{return nil;}
+(UIColor *)color14{return nil;}
+(UIColor *)color15{return nil;}

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

@end
