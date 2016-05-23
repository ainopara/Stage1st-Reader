//
//  S1TopicListCell.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/27/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1TopicListCell.h"
#import "S1TopicListCellSubView.h"
#import <Masonry/Masonry.h>

@interface S1TopicListCell ()

@property (strong, nonatomic) S1TopicListCellSubView *drawingSubview;

@end

@implementation S1TopicListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.drawingSubview = [[S1TopicListCellSubView alloc] initWithFrame:CGRectZero];
        self.drawingSubview.contentMode = UIViewContentModeRedraw;
        [self.contentView addSubview:self.drawingSubview];
        [self.drawingSubview mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.numberOfLines = 2;
        [self.contentView addSubview:_titleLabel];

        [_titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.trailing.equalTo(self.contentView).offset(-20.0);
            make.centerY.equalTo(self.contentView.mas_centerY);
        }];
    }
    return self;
}

- (void)setTopic:(S1Topic *)topic {
    _topic = topic;
    [self.drawingSubview setTopic:topic];
    [self.drawingSubview setNeedsDisplay];

    [_titleLabel setAttributedText:[self attributedTopicTitle]];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self.drawingSubview setHighlighted:selected];
    [self.drawingSubview setNeedsDisplay];
    // Configure the view for the selected state
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self.drawingSubview setHighlighted:highlighted];
    [self.drawingSubview setNeedsDisplay];
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
