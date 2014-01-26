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
+(UIColor *)color5{return [UIColor colorWithRed:0.96 green:0.97 blue:0.90 alpha:1.0];}
+(UIColor *)color6{return [UIColor colorWithWhite:0.20f alpha:1.0f];}
+(UIColor *)color7{return nil;}
+(UIColor *)color8{return nil;}
+(UIColor *)color9{return nil;}
+(UIColor *)color10{return nil;}
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

@end
