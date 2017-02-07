//
//  S1TopicListViewController.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    S1TopicListHistory,
    S1TopicListFavorite
} S1InternalTopicListType;

@interface S1TopicListViewController : UIViewController

@property (nonatomic, strong, readonly) S1DataCenter *dataCenter;

@end
