//
//  S1TopicListViewModel.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@class S1DataCenter;

@interface S1TopicListViewModel : NSObject
- (id)initWithDataCenter:(S1DataCenter *)dataCenter;
- (void)topicListForKey:(NSString *)key finish:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;


@end
