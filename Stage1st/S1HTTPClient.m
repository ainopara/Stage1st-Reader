//
//  S1HTTPClient.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1HTTPClient.h"
#import "AFNetworking.h"


@implementation S1HTTPClient 

+ (S1HTTPClient *)sharedClient
{
    static S1HTTPClient *httpClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        httpClient = [[S1HTTPClient alloc] initWithBaseURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"]]];
        httpClient.responseSerializer = [AFHTTPResponseSerializer serializer];
    });
    return httpClient;
}

+ (S1HTTPClient *)sharedJSONClient
{
    static S1HTTPClient *httpClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        httpClient = [[S1HTTPClient alloc] initWithBaseURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"]]];
        httpClient.responseSerializer = [AFJSONResponseSerializer serializer];
        httpClient.responseSerializer.acceptableContentTypes = [httpClient.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    });
    return httpClient;
}

@end
