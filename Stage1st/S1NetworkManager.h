//
//  S1NetworkManager.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@class S1Topic;

@interface S1NetworkManager : NSObject

- (void)requestTopicListForKey:(NSString *)key
                      withPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

- (void)requestTopicContentForID:(NSNumber *)topicID
                      withPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

- (void)requestReplyRefereanceContentForTopicID:(NSNumber *)topicID
                                       withPage:(NSNumber *)page
                                        floorID:(NSNumber *)floorID
                                        fieldID:(NSNumber *)fieldID
                                        success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                                        failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;
// Reply Specific Floor.
- (void)postReplyForTopicID:(NSNumber *)topicID
                   withPage:(NSNumber *)page
                    fieldID:(NSNumber *)fieldID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                    failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;
// Reply Topic.
- (void)postReplyForTopicID:(NSNumber *)topicID
                    fieldID:(NSNumber *)fieldID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                    failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

+ (void)postLoginForUsername:(NSString *)username
                 andPassword:(NSString *)password
                     success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                     failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

- (void)cancelRequest;

@end