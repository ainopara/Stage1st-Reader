//
//  S1TopicListViewModel.m
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1TopicListViewModel.h"
#import "S1DataCenter.h"
#import "S1Topic.h"




@interface S1TopicListViewModel ()

@property (nonatomic, strong) S1DataCenter *dataCenter;

@end

@implementation S1TopicListViewModel

- (id)initWithDataCenter:(S1DataCenter *)dataCenter {
    self = [super init];
    if (self) {
        // Initialization code
        self.dataCenter = dataCenter;
    }
    return self;
}

- (void)topicListForKey:(NSString *)key shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    [self.dataCenter topicsForKey:key shouldRefresh:refresh success:^(NSArray *topicList) {
        success(topicList);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

@end
