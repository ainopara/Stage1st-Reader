//
//  S1TopicListCell.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/27/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1TopicListCell.h"
#import "S1TopicListCellSubView.h"
#import "S1Topic.h"

@implementation S1TopicListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.autoresizesSubviews = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.contentView.autoresizesSubviews = YES;
        self.contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.drawingSubView = [[S1TopicListCellSubView alloc] initWithFrame:self.contentView.bounds]; //This value will be replaced by setFrame function
        [self.drawingSubView setContentMode:UIViewContentModeRedraw];
        [self.contentView addSubview:self.drawingSubView];
        self.backgroundColor = [S1GlobalVariables color5];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.drawingSubView = [[S1TopicListCellSubView alloc] initWithFrame:self.contentView.bounds]; //This value will be replaced by setFrame function
        [self.drawingSubView setContentMode:UIViewContentModeRedraw];
        [self.contentView addSubview:self.drawingSubView];
        self.backgroundColor = [S1GlobalVariables color5];
    }
    return self;
}

- (void)setTopic:(S1Topic *)topic
{
    _topic = topic;
    [self.drawingSubView setTopic:topic];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self.drawingSubView setSelected:selected];
    [self.drawingSubView setNeedsDisplay];
    // Configure the view for the selected state
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self.drawingSubView setHighlighted:highlighted];
    [self.drawingSubView setNeedsDisplay];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self.drawingSubView setFrame:self.contentView.bounds];
}

@end
