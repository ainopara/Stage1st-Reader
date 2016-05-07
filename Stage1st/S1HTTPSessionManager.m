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
        jsonClient.responseSerializer = [AFJSONResponseSerializer serializer];
        jsonClient.responseSerializer.acceptableContentTypes = [jsonClient.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    });
    return jsonClient;
}

+ (S1HTTPSessionManager *)sharedImageClient
{
    static S1HTTPSessionManager *imageClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        imageClient = [[S1HTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"]]];
        imageClient.responseSerializer = [AFImageResponseSerializer serializer];
    });
    return imageClient;
}

@end
