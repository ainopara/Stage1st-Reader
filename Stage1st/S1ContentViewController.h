//
//  S1ContentViewController.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class S1Topic, S1DataCenter, S1ContentViewModel;

NS_ASSUME_NONNULL_BEGIN

@interface S1ContentViewController : UIViewController

@property (nonatomic, strong) S1ContentViewModel *viewModel;
@property (nonatomic, strong, readonly) S1DataCenter *dataCenter;

- (instancetype)initWithTopic:(S1Topic *)topic dataCenter:(S1DataCenter *)dataCenter;
- (instancetype)initWithViewModel:(S1ContentViewModel *)viewModel;

// Expose to extension
- (void)presentReplyViewToFloor: (Floor * _Nullable)topicFloor;
@end

NS_ASSUME_NONNULL_END
