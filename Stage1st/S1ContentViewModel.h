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

@interface S1ContentViewModel : NSObject

- (id)initWithDataCenter:(S1DataCenter *)dataCenter;

- (void)contentPageForTopic:(S1Topic *)topic withPage:(NSUInteger)page success:(void (^)(NSString *contents))success  failure:(void (^)(NSError *error))failure;

@end
