//
//  S1CacheDatabaseManager.h
//  Stage1st
//
//  Created by Zheng Li on 8/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const Collection_TopicFloors;
extern NSString *const Collection_Headers;

@interface S1CacheDatabaseManager : NSObject
+ (S1CacheDatabaseManager *)sharedInstance;

- (void)setCacheValue:(id)value forKey:(NSString *)key inCollection:(NSString *)collection;
- (id)cacheValueForKey:(NSString *)key inCollection:(NSString *)collection;
- (BOOL)hasCacheForKey:(NSString *)key inCollection:(NSString *)collection;
- (void)removeCacheForKey:(NSString *)key inCollection:(NSString *)collection;
@end
