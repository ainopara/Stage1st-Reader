//
//  S1HTTPClient.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1HTTPClient.h"
#import "AFNetworking.h"

static NSString * const baseURLString = @"http://bbs.saraba1st.com/2b/";

@implementation S1HTTPClient 

+ (S1HTTPClient *)sharedClient
{
    static S1HTTPClient *httpClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        httpClient = [[S1HTTPClient alloc] initWithBaseURL:[NSURL URLWithString:baseURLString]];
    });
    return httpClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (!self) return nil;
    [self registerHTTPOperationClass:[AFHTTPRequestOperation class]];
    return self;
}

@end
