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

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _selected = NO;
        _highlighted = NO;
    }
    return self;
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
    UIColor* cellBackgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.background.normal"];
    if (self.selected || self.highlighted) {
        cellBackgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.background.highlight"];
    }
    UIColor* replyCountRectFillColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.fill"];
    UIColor* replyCountRectStrokeColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.border.normal"];
    UIColor* replyCountRectStrokeColorOfHistoryThread = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.border.history"];
    UIColor* replyCountRectStrokeColorOfFavoriteThread = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.border.favorite"];
    
    UIColor* replyCountTextColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.text.normal"];
    UIColor* replyCountTextColorOfHistoryThread = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.text.history"];
    UIColor* replyCountTextColorOfFavoriteThread = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.text.favorite"];
    
    UIColor* titleColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.title.text"];
    //// Abstracted Attributes
    NSString* textContent = [NSString stringWithFormat:@"%@", self.topic.replyCount];
    
    //Init Attribute Title
    NSMutableParagraphStyle *titleParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    titleParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    titleParagraphStyle.alignment = NSTextAlignmentLeft;
    NSMutableAttributedString *titleContent = [[NSMutableAttributedString alloc] initWithString:self.topic.title == nil ? @"":self.topic.title attributes:@{NSForegroundColorAttributeName: titleColor, NSParagraphStyleAttributeName: titleParagraphStyle}];
    if (self.topic.highlight != nil && (![self.topic.highlight isEqualToString:@""])) {
        [titleContent addAttributes:@{NSForegroundColorAttributeName:[[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.title.highlight"]} range:[[titleContent string] rangeOfString:self.topic.highlight options:NSWidthInsensitiveSearch | NSCaseInsensitiveSearch]];
    }
    
    
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
        CGRect actualRect = [[titleContent string] boundingRectWithSize:titleRect.size options:NSStringDrawingTruncatesLastVisibleLine + NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15.0f], NSParagraphStyleAttributeName: testParagraphStyle} context:nil];
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
    
    
    //// Reply Count Text Drawing
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
    
    // Draw Reply Increment Text
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ReplyIncrement"]) {
        if (self.topic.lastReplyCount) {
            NSNumber *replyCountChanged = @([self.topic.replyCount longLongValue] - [self.topic.lastReplyCount longLongValue]);
            if ([replyCountChanged longLongValue] > 0) {
                NSString* replyChangeContent = [NSString stringWithFormat:@"+%@", replyCountChanged];
                NSMutableParagraphStyle *replyCountParagraphStyle = [[NSMutableParagraphStyle alloc] init];
                replyCountParagraphStyle.lineBreakMode = NSLineBreakByClipping;
                replyCountParagraphStyle.alignment = NSTextAlignmentCenter;
                CGRect rect = CGRectMake(20, 38, 35, 16);
                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                    rect = CGRectMake(20 + 10, 38, 35, 16);
                }
                [replyChangeContent drawInRect:rect withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:10.0f],
                                                                                           NSParagraphStyleAttributeName: replyCountParagraphStyle,
                                                                                           NSForegroundColorAttributeName: replyCountFinalColor}];
            }
        }
    }
    
    
    //// Title Drawing
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [titleContent addAttribute:NSFontAttributeName value: [UIFont systemFontOfSize:15.0f] range:NSMakeRange(0, titleContent.length)];
        [titleContent drawInRect:titleRect];
    } else {
        [titleContent addAttribute:NSFontAttributeName value: [UIFont systemFontOfSize:17.0f] range:NSMakeRange(0, titleContent.length)];
        [titleContent drawAtPoint:titlePoint];
    }
}
- (NSString *)accessibilityLabel {
    return self.topic.title;
}

- (BOOL)isAccessibilityElement {
    return YES;
}
@end
