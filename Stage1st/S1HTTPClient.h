//
//  S1HTTPClient.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "AFHTTPSessionManager.h"

@interface S1HTTPClient : AFHTTPSessionManager

+ (S1HTTPClient *)sharedClient;

+ (S1HTTPClient *)sharedJSONClient;

@end
