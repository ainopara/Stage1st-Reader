//
//  S1NetworkManager.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@class S1Topic;

NS_ASSUME_NONNULL_BEGIN

@interface S1NetworkManager : NSObject

- (instancetype)initWithBaseURL:(NSString *)baseURL;

- (void)requestTopicContentAPIForID:(NSNumber *)topicID
                           withPage:(NSNumber *)page
                            success:(void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                            failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *error))failure;

#pragma mark - Reply

- (void)requestReplyRefereanceContentForTopicID:(NSNumber *)topicID
                                       withPage:(NSNumber *)page
                                        floorID:(NSNumber *)floorID
                                        forumID:(NSNumber *)forumID
                                        success:(void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                                        failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *error))failure;
// Reply Specific Floor.
- (void)postReplyForTopicID:(NSNumber *)topicID
                   withPage:(NSNumber *)page
                    forumID:(NSNumber *)forumID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                    failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *error))failure;
// Reply Topic.
- (void)postReplyForTopicID:(NSNumber *)topicID
                    forumID:(NSNumber *)forumID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                    failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *error))failure;

#pragma mark - Search

- (void)postSearchForKeyword:(NSString *)keyword
                 andFormhash:(NSString *)formhash
                     success:(void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                     failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *error))failure;

#pragma mark - User Info

- (void)requestThreadListForID:(NSNumber *)userID
                       andPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *error))failure;

- (void)requestReplyListForID:(NSNumber *)userID
                      andPage:(NSNumber *)page
                      success:(void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *error))failure;

#pragma mark - Misc

- (void)cancelRequest;

@end

NS_ASSUME_NONNULL_END
