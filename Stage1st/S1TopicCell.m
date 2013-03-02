//
//  S1TopicCell.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/20/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1TopicCell.h"
#import "S1Topic.h"
#import <CoreText/CoreText.h>

@implementation S1TopicCell

- (void)setTopic:(S1Topic *)topic
{
    _topic = topic;
    self.contentView.layer.contents = nil;
    [self setNeedsDisplay];
}

- (void)asyncDrawRect:(CGRect)rect andContext:(CGContextRef)context
{
    UIGraphicsPushContext(context);
    
    //// Color Declarations
    UIColor* fill = [UIColor colorWithRed: 0.929 green: 0.922 blue: 0.89 alpha: 1];
    UIColor* outerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.5];
    UIColor* stroke = [UIColor colorWithRed: 0.757 green: 0.749 blue: 0.698 alpha: 1];
    UIColor* background = [UIColor colorWithRed: 0.973 green: 0.969 blue: 0.953 alpha: 1];
    if (self.selected || self.highlighted) {
        background = [UIColor whiteColor];
    }
    UIColor* replyTextColor = [UIColor colorWithRed: 0.647 green: 0.643 blue: 0.616 alpha: 1];
    
    
    
    //// Shadow Declarations
    UIColor* outerShadow = outerShadowColor;
    CGSize outerShadowOffset = CGSizeMake(0.1, -0.1);
    CGFloat outerShadowBlurRadius = 4.0;
    
    //// Abstracted Attributes
    NSString* textContent = self.topic.replyCount;
    NSString* titleContent = self.topic.title;
    
    
    //// Rectangle Drawing
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(0, 0, 320, 60)];
    [background setFill];
    [rectanglePath fill];
    
    //// Rounded Rectangle Drawing
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: CGRectMake(20, 20, 35, 20) cornerRadius:2];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, outerShadowOffset, outerShadowBlurRadius, outerShadow.CGColor);
    [fill setFill];
    [roundedRectanglePath fill];
    CGContextRestoreGState(context);
    
    [stroke setStroke];
    roundedRectanglePath.lineWidth = 1.0;
    [roundedRectanglePath stroke];
    
    
    //// Text Drawing
    CGRect textRect = CGRectMake(20, 22.5, 35, 18);
    [replyTextColor setFill];
    [textContent drawInRect: textRect withFont: [UIFont boldSystemFontOfSize:12.0f] lineBreakMode: NSLineBreakByClipping alignment: NSTextAlignmentCenter];
    
    //// Title Drawing
    CGRect titleRect = CGRectMake(70, 10, 230, 38);
    [[UIColor darkGrayColor] setFill];
    [titleContent drawInRect: titleRect withFont:[UIFont boldSystemFontOfSize:15.0f] lineBreakMode: NSLineBreakByTruncatingTail alignment: NSTextAlignmentLeft];
    
    UIGraphicsPopContext();
}


@end
