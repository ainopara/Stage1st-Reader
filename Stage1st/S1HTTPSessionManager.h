//
//  S1HTTPClient.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "AFHTTPSessionManager.h"

@interface S1HTTPSessionManager : AFHTTPSessionManager

+ (S1HTTPSessionManager *)sharedHTTPClient;

+ (S1HTTPSessionManager *)sharedJSONClient;

@end
