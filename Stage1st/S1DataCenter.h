//
//  S1DataCenter.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S1DataCenter : NSObject
- (BOOL)hasCacheForKey:(NSString *)keyID;
- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;
- (void)loadNextPageForKey:(NSString *)keyID success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;
@end
