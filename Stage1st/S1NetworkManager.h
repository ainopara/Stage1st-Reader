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

+ (void)requestTopicListForKey:(NSString *)key
                      withPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

+ (void)requestTopicContentForID:(NSNumber *)topicID
                      withPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

//API
+ (void)checkLoginStateAPIwithSuccessBlock:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                              failureBlock:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

+ (void)requestTopicListAPIForKey:(NSString *)key
                      withPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

+ (void)requestTopicContentAPIForID:(NSNumber *)topicID
                           withPage:(NSNumber *)page
                            success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                            failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;


+ (void)requestReplyRefereanceContentForTopicID:(NSNumber *)topicID
                                       withPage:(NSNumber *)page
                                        floorID:(NSNumber *)floorID
                                        forumID:(NSNumber *)forumID
                                        success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                                        failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;
// Reply Specific Floor.
+ (void)postReplyForTopicID:(NSNumber *)topicID
                   withPage:(NSNumber *)page
                    forumID:(NSNumber *)forumID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                    failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;
// Reply Topic.
+ (void)postReplyForTopicID:(NSNumber *)topicID
                    forumID:(NSNumber *)forumID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                    failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;
// Login
+ (void)postLoginForUsername:(NSString *)username
                 andPassword:(NSString *)password
                     success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                     failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

+ (void)requestLogoutCurrentAccountWithFormhash:(NSString *)formhash
                                        success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                                        failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;


+ (void)findTopicFloor:(NSNumber *)floorID
             inTopicID:(NSNumber *)topicID
               success:(void (^)(NSURLSessionDataTask *, id))success
               failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

// Search
+ (void)postSearchForKeyword:(NSString *)keyword
                 andFormhash:(NSString *)formhash
                     success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                     failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;
// User Info
+ (void)requestThreadListForID:(NSNumber *)userID
                       andPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

+ (void)requestReplyListForID:(NSNumber *)userID
                      andPage:(NSNumber *)page
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;


+ (void)cancelRequest;

@end
