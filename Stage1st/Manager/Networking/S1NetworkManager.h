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
