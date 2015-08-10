//
//  S1TopicListCell.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/27/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class S1Topic;
@class S1TopicListCellSubView;

@interface S1TopicListCell : UITableViewCell

@property (nonatomic, strong) S1Topic *topic;
@property (nonatomic, strong) NSString *highlight;

- (void)updateSubview;

@end
