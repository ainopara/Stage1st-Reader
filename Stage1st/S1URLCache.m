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
    NSString *prefix = [NSString stringWithFormat:@"%@static/image/smiley", baseURLString];
    
    if ([URLString hasPrefix:prefix]) { // when request mahjong
        NSString *localPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/Mahjong"];
        NSRange range = [URLString rangeOfString:prefix];
        NSString *suffix = [URLString substringFromIndex:range.location + range.length];
        NSString *fullPath = [NSString stringWithFormat:@"%@%@", localPath, suffix];
        NSData *imageData = [NSData dataWithContentsOfFile:fullPath];
        
        if (imageData) {
            NSURLResponse *response =
            [[NSURLResponse alloc] initWithURL:request.URL
                                      MIMEType:@"image/png"
                         expectedContentLength:[imageData length]
                              textEncodingName:nil];
            NSCachedURLResponse *cachedResponse =
            [[NSCachedURLResponse alloc] initWithResponse:response
                                                     data:imageData];
            return cachedResponse;
        } else {
            NSLog(@"smiley not cached: %@", URLString);
            return [super cachedResponseForRequest:request];
        }
    }
    else if ([URLString hasPrefix:baseURLString]) { // when request webpages or attachments
        return [super cachedResponseForRequest:request];
    }
    else { // when request pictures from other websites
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Display"]) {
            NSMutableURLRequest * newRequest = [request mutableCopy];
            [newRequest addValue:@"Referer" forHTTPHeaderField:@"http://bbs.saraba1st.com/2b/thread-1003768-1-2.html"];
            return [super cachedResponseForRequest:newRequest];
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
