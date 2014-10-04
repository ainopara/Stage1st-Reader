//
//  S1TopicListViewModel.m
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1TopicListViewModel.h"

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

- (void)topicListForKey:(NSString *)key finish:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    ;
}

@end
