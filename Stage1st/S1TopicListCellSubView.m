//
//  S1TopicListCellSubView.m
//  Stage1st
//
//  Created by hanza on 14-1-21.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import "S1TopicListCellSubView.h"
#import "S1Topic.h"
#import <Masonry/Masonry.h>

@implementation S1TopicListCellSubView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _highlighted = NO;
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.numberOfLines = 2;
        [self addSubview:_titleLabel];

        [_titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.trailing.equalTo(self).offset(-20.0);
            make.centerY.equalTo(self.mas_centerY);
        }];
    }
    return self;
}


- (void)setHighlighted:(BOOL)highlighted {
    _highlighted = highlighted;
}

- (void)setTopic:(S1Topic *)topic {
    _topic = topic;
    [_titleLabel setAttributedText:[self attributedTopicTitle]];
}

- (void)setHighlight:(NSString *)highlight {
    _highlight = highlight;
    [_titleLabel setAttributedText:[self attributedTopicTitle]];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    UIUserInterfaceSizeClass horizontalClass = self.traitCollection.horizontalSizeClass;
    if (horizontalClass == UIUserInterfaceSizeClassCompact) {
        [_titleLabel mas_updateConstraints:^(MASConstraintMaker *make) {
            make.leading.equalTo(self).offset(70.0);
        }];
    } else {
        [_titleLabel mas_updateConstraints:^(MASConstraintMaker *make) {
            make.leading.equalTo(self).offset(90.0);
        }];
    }
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Color Declarations
    UIColor *cellBackgroundColor = _highlighted ?
    [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.background.highlight"] :
    [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.background.normal"];

    UIColor *replyCountRectFillColor = [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.fill"];
    UIColor *replyCountRectStrokeColor = [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.border.normal"];
    UIColor *replyCountRectStrokeColorOfHistoryThread = [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.border.history"];
    UIColor *replyCountRectStrokeColorOfFavoriteThread = [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.border.favorite"];
    
    UIColor *replyCountTextColor = [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.text.normal"];
    UIColor *replyCountTextColorOfHistoryThread = [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.text.history"];
    UIColor *replyCountTextColorOfFavoriteThread = [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.replycount.text.favorite"];

    // Abstracted Attributes
    NSString* textContent = [self.topic.replyCount stringValue];
    
    // Background Drawing
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect:self.bounds];
    [cellBackgroundColor setFill];
    [rectanglePath fill];
    
    CGRect roundRectangleRect = CGRectZero;
    CGRect replyCountRect = CGRectZero;
    CGRect replyIncrementCountRect = CGRectZero;

    UIUserInterfaceSizeClass horizontalClass = self.traitCollection.horizontalSizeClass;
    switch (horizontalClass) {
    case UIUserInterfaceSizeClassCompact:
        roundRectangleRect = CGRectMake(19, 18, 37, 19);
        roundRectangleRect = CGRectInset(roundRectangleRect, -2, 0);
        replyCountRect = CGRectMake(20, 20, 35, 18);
        replyCountRect = CGRectInset(replyCountRect, -2, 0);
        replyIncrementCountRect = CGRectMake(20, 38, 35, 16);
        break;
    
    default:
        roundRectangleRect = CGRectMake(19+10, 17, 37, 20);
        roundRectangleRect = CGRectInset(roundRectangleRect, -2, 0);
        replyCountRect = CGRectMake(20+10, 19.5, 35, 18);
        replyCountRect = CGRectInset(replyCountRect, -2, 0);
        replyIncrementCountRect = CGRectMake(20+10, 38, 35, 16);
    }

    // Rounded Rectangle Drawing
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
    [textContent drawInRect:replyCountRect withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12.0f],
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
                [replyChangeContent drawInRect:replyIncrementCountRect withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:10.0f],
                                                                                           NSParagraphStyleAttributeName: replyCountParagraphStyle,
                                                                                           NSForegroundColorAttributeName: replyCountFinalColor}];
            }
        }
    }
}

- (NSString *)accessibilityLabel {
    return self.topic.title;
}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSMutableAttributedString *)attributedTopicTitle {
    NSString *const titleString = self.topic.title == nil ? @"" : self.topic.title;
    UIUserInterfaceSizeClass horizontalClass = self.traitCollection.horizontalSizeClass;
    UIFont *const titleFont = horizontalClass == UIUserInterfaceSizeClassCompact ? [UIFont systemFontOfSize:15.0] : [UIFont systemFontOfSize:17.0];
    UIColor *const titleColor = [[APColorManager sharedInstance] colorForKey:@"topiclist.cell.title.text"];

    NSMutableParagraphStyle *const titleParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    titleParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    titleParagraphStyle.alignment = NSTextAlignmentLeft;

    NSDictionary *const attribute = @{
        NSForegroundColorAttributeName: titleColor,
        NSFontAttributeName: titleFont,
        NSParagraphStyleAttributeName: titleParagraphStyle
    };

    NSMutableAttributedString *const titleContent = [[NSMutableAttributedString alloc] initWithString:titleString attributes:attribute];

    NSDictionary *const highlightAttribute = @{
        NSForegroundColorAttributeName:[[APColorManager sharedInstance] colorForKey:@"topiclist.cell.title.highlight"]
    };

    if (self.highlight != nil && ![self.highlight isEqualToString:@""]) {
        [titleContent addAttributes:highlightAttribute
                              range:[[titleContent string] rangeOfString:self.highlight options:NSWidthInsensitiveSearch | NSCaseInsensitiveSearch]];
    }

    return titleContent;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    _titleLabel.attributedText = [self attributedTopicTitle];
}

@end
