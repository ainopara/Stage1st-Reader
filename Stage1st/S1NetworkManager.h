//
//  S1NetworkManager.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S1NetworkManager : NSObject

- (void)requestTopicListForKey:(NSString *)key
                      withPage:(NSUInteger)page
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

- (void)requestTopicContentForID:(NSNumber *)topicID
                      withPage:(NSUInteger)page
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

- (void)cancelRequest;

@end
