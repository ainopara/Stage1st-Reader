//
//  S1ContentViewModel.h
//  Stage1st
//
//  Created by Zheng Li on 10/9/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@class S1DataCenter;
@class S1Topic;

NS_ASSUME_NONNULL_BEGIN

@interface S1ContentViewModel : NSObject

@property (nonatomic, strong, readonly) S1Topic *topic;
@property (nonatomic, strong, readonly) S1DataCenter *dataCenter;

@property (nonatomic, assign) NSUInteger currentPage;
@property (nonatomic, assign, readonly) NSUInteger previousPage;
@property (nonatomic, assign) NSUInteger totalPages;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *cachedViewPosition;

- (instancetype)initWithTopic:(S1Topic *)topic dataCenter:(S1DataCenter *)dataCenter;

@end

NS_ASSUME_NONNULL_END
