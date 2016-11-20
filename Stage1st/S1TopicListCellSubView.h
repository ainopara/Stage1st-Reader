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

@property (nonatomic, strong) S1Topic *topic;
@property (nonatomic, assign) BOOL highlighted;
@property (nonatomic, assign) BOOL pinningToTop;

@end
