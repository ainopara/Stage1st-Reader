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
        NSLog(@"Style: %f-%f-%f-%f",self.frame.size.height,self.frame.size.width,self.frame.origin.x,self.frame.origin.y);
        self.drawingSubView = [[S1TopicListCellSubView alloc] initWithFrame:self.contentView.bounds];
        [self.contentView addSubview:self.drawingSubView];
    }
    return self;
}

- (void)setTopic:(S1Topic *)topic
{
    [self.drawingSubView setTopic:topic];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self.drawingSubView setSelected:selected];
    if (selected) {
        NSLog(@"selected");
    }
    // Configure the view for the selected state
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self.drawingSubView setHighlighted:highlighted];
    if (highlighted) {
        NSLog(@"highlighted");
    }
}



@end
