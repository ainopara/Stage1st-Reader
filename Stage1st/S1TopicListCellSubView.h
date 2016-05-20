//
//  S1TopicListCellSubView.h
//  Stage1st
//
//  Created by hanza on 14-1-21.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class S1Topic;

@interface S1TopicListCellSubView : UIView

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) S1Topic *topic;
@property (nonatomic, strong) NSString *highlight;
@property (nonatomic, assign) BOOL highlighted;

@end
