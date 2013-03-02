//
//  S1TopicListCell.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/27/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1TopicListCell.h"
#import "S1Topic.h"

@implementation S1TopicListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setTopic:(S1Topic *)topic
{
    _topic = topic;
    [self setNeedsDisplay];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
    [self setNeedsDisplay];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* fill = [UIColor colorWithRed: 0.96 green: 0.97 blue: 0.92 alpha: 1];
    UIColor* outerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.5];
    UIColor* stroke = [UIColor colorWithRed: 0.757 green: 0.749 blue: 0.698 alpha: 1];
    UIColor* background = [UIColor colorWithRed: 0.96 green: 0.97 blue: 0.92 alpha: 1];
    UIColor* decorateLineColor = [UIColor colorWithWhite:0.98 alpha:1.0];
    if (self.selected || self.highlighted) {
        background = [UIColor colorWithRed: 0.92 green: 0.92 blue: 0.86 alpha: 1];
        decorateLineColor = [UIColor clearColor];
    }
    UIColor* replyTextColor = [UIColor colorWithRed: 0.647 green: 0.643 blue: 0.616 alpha: 1];
    
    
    
    //// Shadow Declarations
    UIColor* outerShadow = outerShadowColor;
    CGSize outerShadowOffset = CGSizeMake(0.1, -0.1);
    CGFloat outerShadowBlurRadius = 1.6;
    
    //// Abstracted Attributes
    NSString* textContent = self.topic.replyCount;
    NSString* titleContent = self.topic.title;
    
    
    //// Rectangle Drawing
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(0, 0, 320, 60)];
    [background setFill];
    [rectanglePath fill];
    
    //// Rounded Rectangle Drawing
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: CGRectMake(20, 17, 35, 20) cornerRadius:2];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, outerShadowOffset, outerShadowBlurRadius, outerShadow.CGColor);
    [fill setFill];
    [roundedRectanglePath fill];
    CGContextRestoreGState(context);
    
    [stroke setStroke];
    roundedRectanglePath.lineWidth = 1.0;
    [roundedRectanglePath stroke];
    
    
    //// Text Drawing
    CGRect textRect = CGRectMake(20, 19.5, 35, 18);
    [replyTextColor setFill];
    [textContent drawInRect: textRect withFont: [UIFont boldSystemFontOfSize:12.0f] lineBreakMode: NSLineBreakByClipping alignment: NSTextAlignmentCenter];
    
    //// Title Drawing
    CGRect titleRect = CGRectMake(70, 8, 230, 38);
    [[UIColor colorWithRed: 0.01 green: 0.17 blue: 0.50 alpha:0.9] setFill];
    [titleContent drawInRect: titleRect withFont:[UIFont boldSystemFontOfSize:15.0f] lineBreakMode: NSLineBreakByTruncatingTail alignment: NSTextAlignmentLeft];
    
    [decorateLineColor set];
    CGContextSetLineWidth(context, 2.0);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, rect.size.width, 0);
    CGContextStrokePath(context);

    
}

@end
