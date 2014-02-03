//
//  S1URLCache.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/25/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1URLCache.h"

@implementation S1URLCache


- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    NSString *URLString = [[request URL] absoluteString];
    NSString *baseURLString = [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"];
    NSString *prefix = [NSString stringWithFormat:@"%@/2b/static/image/smiley", baseURLString];
    if ([URLString hasPrefix:prefix]) {
        NSString *localPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/Mahjong"];
        NSRange range = [URLString rangeOfString:prefix];
        NSString *suffix = [URLString substringFromIndex:range.location + range.length];
        NSString *fullPath = [NSString stringWithFormat:@"%@%@", localPath, suffix];
        NSData *imageData = [NSData dataWithContentsOfFile:fullPath];
        NSURLResponse *response =
        [[NSURLResponse alloc] initWithURL:request.URL
                                  MIMEType:@"image/png"
                     expectedContentLength:[imageData length]
                          textEncodingName:nil];
        
        NSCachedURLResponse *cachedResponse =
        [[NSCachedURLResponse alloc] initWithResponse:response
                                                 data:imageData];
        return cachedResponse;
    }
    else if ([URLString hasPrefix:baseURLString]) {
        return [super cachedResponseForRequest:request];
    }
    else {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Display"]) {
            return [super cachedResponseForRequest:request];
        }
        else {
            NSData *imageData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Placeholder" ofType:@"png"]];
            NSURLResponse *response =
            [[NSURLResponse alloc] initWithURL:request.URL
                                      MIMEType:@"image/png"
                         expectedContentLength:[imageData length]
                              textEncodingName:nil];
            
            NSCachedURLResponse *cachedResponse =
            [[NSCachedURLResponse alloc] initWithResponse:response
                                                     data:imageData];
            return cachedResponse;
        }
    }
}

@end
