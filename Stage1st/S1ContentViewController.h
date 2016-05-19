//
//  S1ContentViewController.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class S1Topic, S1DataCenter;

NS_ASSUME_NONNULL_BEGIN

@interface S1ContentViewController : UIViewController

@property (nonatomic, strong, readonly) S1Topic *topic;

@property (nonatomic, strong, readonly) S1DataCenter *dataCenter;

- (instancetype)initWithTopic:(S1Topic *)topic dataCenter:(S1DataCenter *)dataCenter;

@end

NS_ASSUME_NONNULL_END
