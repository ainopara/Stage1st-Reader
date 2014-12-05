//
//  S1HTTPClient.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1HTTPSessionManager.h"
#import "AFNetworking.h"


@implementation S1HTTPSessionManager

+ (S1HTTPSessionManager *)sharedHTTPClient
{
    static S1HTTPSessionManager *httpClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        httpClient = [[S1HTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"]]];
        httpClient.responseSerializer = [AFHTTPResponseSerializer serializer];
    });
    return httpClient;
}

+ (S1HTTPSessionManager *)sharedJSONClient
{
    static S1HTTPSessionManager *jsonClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jsonClient = [[S1HTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"]]];
        //httpClient.requestSerializer = [AFHTTPRequestSerializer serializer];
        //[httpClient.requestSerializer setValue:@"Mozilla/5.0 Gecko/20100101 Stage1st" forHTTPHeaderField:@"User-Agent"];
        jsonClient.responseSerializer = [AFJSONResponseSerializer serializer];
        jsonClient.responseSerializer.acceptableContentTypes = [jsonClient.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    });
    return jsonClient;
}

@end
