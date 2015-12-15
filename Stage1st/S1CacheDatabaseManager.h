//
//  S1CacheDatabaseManager.h
//  Stage1st
//
//  Created by Zheng Li on 8/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
@class S1Floor;

@interface S1CacheDatabaseManager : NSObject
+ (S1CacheDatabaseManager *)sharedInstance;

- (void)setFloorArray:(NSArray *)floors inTopicID:(NSNumber *)topicID ofPage:(NSNumber *)page finishBlock:(dispatch_block_t)block;
- (NSArray *)cacheValueForTopicID:(NSNumber *)topicID withPage:(NSNumber *)page;
- (BOOL)hasCacheForTopicID:(NSNumber *)topicID withPage:(NSNumber *)page;
- (void)removeCacheForKey:(NSString *)key;

- (S1Floor *)findFloorByID:(NSNumber *)floorID;

- (void)removeCacheLastUsedBeforeDate:(NSDate *)date;

- (void)saveMahjongFaceHistory:(NSMutableArray *)historyArray;
- (NSMutableArray *)mahjongFaceHistory;
@end
