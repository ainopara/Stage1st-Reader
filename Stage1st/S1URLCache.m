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
    NSString *placeholder = @"stage1streader-placeholder.png";
    
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
            DDLogWarn(@"[URLCache] Smiley not cached: %@", URLString);
            return [super cachedResponseForRequest:request];
        }
    } else if ([URLString hasSuffix:placeholder]) {
        UIImage *image = [UIImage imageNamed:@"Placeholder"];
        NSData *imageData = UIImagePNGRepresentation(image);
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL MIMEType:@"image/png" expectedContentLength:[imageData length] textEncodingName:nil];
        
        NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:imageData];
        return cachedResponse;
    } else if ([URLString hasPrefix:baseURLString]) { // when request webpages or attachments
        return [super cachedResponseForRequest:request];
    } else { // when request pictures from other websites
        NSMutableURLRequest * newRequest = [request mutableCopy];
        [newRequest addValue:@"http://bbs.saraba1st.com/2b/forum.php" forHTTPHeaderField:@"Referer"];
        // NSLog(@"%@", [newRequest allHTTPHeaderFields]);
        return [super cachedResponseForRequest:newRequest];
    }
}

@end
