//
//  S1HTTPClient.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "AFHTTPSessionManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface S1HTTPSessionManager : AFHTTPSessionManager

- (instancetype)initToHTTPClientWithBaseURL:(NSString *)baseURL;

@end

NS_ASSUME_NONNULL_END
