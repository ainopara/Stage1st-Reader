//
//  S1HTTPClient.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1HTTPSessionManager.h"
#import "AFNetworking.h"

NS_ASSUME_NONNULL_BEGIN

@implementation S1HTTPSessionManager

- (instancetype)initToHTTPClientWithBaseURL:(NSString *)baseURL
{
    self = [super initWithBaseURL:[NSURL URLWithString:baseURL]];

    if (self != nil) {
        self.responseSerializer = [AFHTTPResponseSerializer serializer];
    }

    return self;
}

@end

NS_ASSUME_NONNULL_END
