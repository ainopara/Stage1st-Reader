//
//  S1DatabaseListCell.m
//  Stage1st
//
//  Created by Zheng Li on 12/28/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1DatabaseListCell.h"

@implementation S1DatabaseListCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    if (self.selected) {
        [self setSelected:NO animated:animated];
    }
    
    // Configure the view for the selected state
}

@end
