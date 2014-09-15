//
//  S1TopicListCellSubView.m
//  Stage1st
//
//  Created by hanza on 14-1-21.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import "S1TopicListCellSubView.h"
#import "S1Topic.h"
@implementation S1TopicListCellSubView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        _selected = NO;
        _highlighted = NO;
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
    _selected = selected;
}
     
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    _highlighted = highlighted;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* cellBackgroundColor = [UIColor colorWithRed: 0.96 green: 0.97 blue: 0.92 alpha: 1];
    if (self.selected || self.highlighted) {
        cellBackgroundColor = [UIColor colorWithRed: 0.92 green: 0.92 blue: 0.86 alpha: 1];
    }
    UIColor* replyCountRectFillColor = [UIColor clearColor];
    UIColor* replyCountRectStrokeColor = [UIColor colorWithRed: 0.757 green: 0.749 blue: 0.698 alpha: 1];
    UIColor* replyCountRectStrokeColorOfHistoryThread = [UIColor colorWithRed:0.290 green:0.565 blue:0.886 alpha:1.000];
    UIColor* replyCountRectStrokeColorOfFavoriteThread = [UIColor colorWithRed:0.988 green:0.831 blue:0.416 alpha:1.000];
    
    UIColor* replyCountTextColor = [UIColor colorWithRed: 0.647 green: 0.643 blue: 0.616 alpha: 1];
    UIColor* replyCountTextColorOfHistoryThread = [UIColor colorWithRed:0.000 green:0.475 blue:1.000 alpha:1.000];
    UIColor* replyCountTextColorOfFavoriteThread = [UIColor colorWithRed:0.961 green:0.651 blue:0.137 alpha:1.000];
    
    UIColor* titleColor = [UIColor colorWithRed: 0.01 green: 0.17 blue: 0.50 alpha:1.0];
    //// Abstracted Attributes
    NSString* textContent = [NSString stringWithFormat:@"%@", self.topic.replyCount];
    
    
    NSString* titleContent = self.topic.title;
    
    
    //// Rectangle Drawing
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect:self.bounds];
    [cellBackgroundColor setFill];
    [rectanglePath fill];
    
    CGRect roundRectangleRect = CGRectZero;
    CGRect textRect = CGRectZero;
    CGRect titleRect = CGRectZero;
    CGPoint titlePoint = CGPointZero;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        roundRectangleRect = CGRectMake(19, 18, 37, 19);
        textRect = CGRectMake(20, 20, 35, 18);
        titleRect = CGRectMake(70, 8, self.bounds.size.width - 90, 38);
        
        NSMutableParagraphStyle *testParagraphStyle = [[NSMutableParagraphStyle alloc] init];
        testParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
        testParagraphStyle.alignment = NSTextAlignmentLeft;
        CGRect actualRect = [titleContent boundingRectWithSize:titleRect.size options:NSStringDrawingTruncatesLastVisibleLine + NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15.0f], NSParagraphStyleAttributeName: testParagraphStyle} context:nil];
        if (actualRect.size.height < 30.0f) {
            titleRect = CGRectMake(70, 18, self.bounds.size.width - 90, 33);
        }
        
    }
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        roundRectangleRect = CGRectMake(19+10, 17, 37, 20);
        textRect = CGRectMake(20+10, 19.5, 35, 18);
        CGFloat fontHeight = [UIFont boldSystemFontOfSize:18.0].lineHeight;
        titlePoint = CGPointMake(90, roundf((self.bounds.size.height-fontHeight)/2)-0.5);
    }
    
    //// Rounded Rectangle Drawing
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect:roundRectangleRect cornerRadius:2];
    CGContextSaveGState(context);
    [replyCountRectFillColor setFill];
    [roundedRectanglePath fill];
    CGContextRestoreGState(context);
    if ([self.topic.favorite  isEqual: @1]) {
        [replyCountRectStrokeColorOfFavoriteThread setStroke];
    } else if (self.topic.lastViewedPosition) {
        [replyCountRectStrokeColorOfHistoryThread setStroke];
    } else {
        [replyCountRectStrokeColor setStroke];
    }
    roundedRectanglePath.lineWidth = 0.8;
    [roundedRectanglePath stroke];
    
    
    //// Text Drawing
    UIColor *replyCountFinalColor = nil;
    if ([self.topic.favorite  isEqual: @1]) {
        replyCountFinalColor = replyCountTextColorOfFavoriteThread;
    } else if (self.topic.lastViewedPosition) {
        replyCountFinalColor = replyCountTextColorOfHistoryThread;
    } else {
        replyCountFinalColor = replyCountTextColor;
    }
    NSMutableParagraphStyle *replyCountParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    replyCountParagraphStyle.lineBreakMode = NSLineBreakByClipping;
    replyCountParagraphStyle.alignment = NSTextAlignmentCenter;
    [textContent drawInRect:textRect withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12.0f],
                                                      NSParagraphStyleAttributeName: replyCountParagraphStyle,
                                                      NSForegroundColorAttributeName: replyCountFinalColor}];
    
    if (self.topic.lastReplyCount) {
        NSNumber *replyCountChanged = @([self.topic.replyCount longLongValue] - [self.topic.lastReplyCount longLongValue]);
        if (replyCountChanged > 0) {
            NSString* replyChangeContent = [NSString stringWithFormat:@"+%@", replyCountChanged];
            NSMutableParagraphStyle *replyCountParagraphStyle = [[NSMutableParagraphStyle alloc] init];
            replyCountParagraphStyle.lineBreakMode = NSLineBreakByClipping;
            replyCountParagraphStyle.alignment = NSTextAlignmentCenter;
            [replyChangeContent drawInRect:CGRectMake(20, 38, 35, 16) withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:10.0f],
                                                                                      NSParagraphStyleAttributeName: replyCountParagraphStyle,
                                                                                      NSForegroundColorAttributeName: replyCountFinalColor}];
        }
        
    }
    
    //// Title Drawing
    NSMutableParagraphStyle *titleParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    titleParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    titleParagraphStyle.alignment = NSTextAlignmentLeft;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [titleContent drawInRect:titleRect withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15.0f],
                                                          NSParagraphStyleAttributeName: titleParagraphStyle,
                                                          NSForegroundColorAttributeName: titleColor}];
    } else {
        [titleContent drawAtPoint:titlePoint withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:17.0f],
                                                            NSParagraphStyleAttributeName: titleParagraphStyle,
                                                            NSForegroundColorAttributeName: titleColor}];
    }
}

@end
