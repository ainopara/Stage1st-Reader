//
//  S1TopicListViewModel.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    S1TopicListHistory,
    S1TopicListFavorite
} S1InternalTopicListType;

@class S1DataCenter;

@interface S1TopicListViewModel : NSObject

- (id)initWithDataCenter:(S1DataCenter *)dataCenter;

- (void)topicListForKey:(NSString *)key shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;

- (NSDictionary *)internalTopicsInfoFor:(S1InternalTopicListType)key withSearchWord:(NSString *)searchWord andLeftCallback:(void (^)(NSDictionary *))leftTopicsHandler;



@end
