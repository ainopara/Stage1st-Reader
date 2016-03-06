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

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.drawingSubview = [[S1TopicListCellSubView alloc] initWithFrame:CGRectZero];
        self.drawingSubview.contentMode = UIViewContentModeRedraw;
        [self.contentView addSubview:self.drawingSubview];
        [self.drawingSubview mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
    }
    return self;
}

- (void)setTopic:(S1Topic *)topic {
    _topic = topic;
    [self.drawingSubview setTopic:topic];
    [self updateSubview];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self.drawingSubview setSelected:selected];
    [self updateSubview];
    // Configure the view for the selected state
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self.drawingSubview setHighlighted:highlighted];
    [self updateSubview];
}

- (void)setHighlight:(NSString *)highlight {
    [self.drawingSubview setHighlight:highlight];
    [self updateSubview];
}

- (void)updateSubview {
    [self.drawingSubview setNeedsDisplay];
}

@end
