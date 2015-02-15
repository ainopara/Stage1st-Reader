//
//  S1TopicListCell.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/27/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1TopicListCell.h"
#import "S1TopicListCellSubView.h"
@interface S1TopicListCell ()

@property (weak, nonatomic) IBOutlet S1TopicListCellSubView *drawingSubview;

@end

@implementation S1TopicListCell

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        self.backgroundColor = [S1Global color5];
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

- (void)updateSubview {
    [self.drawingSubview setNeedsDisplay];
}

@end
