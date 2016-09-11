//
//  S1CacheDatabaseManager.h
//  Stage1st
//
//  Created by Zheng Li on 8/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Floor;

NS_ASSUME_NONNULL_BEGIN

@interface S1CacheDatabaseManager : NSObject

+ (S1CacheDatabaseManager *)sharedInstance;

- (void)setFloorArray:(NSArray<Floor *> *)floors inTopicID:(NSNumber *)topicID ofPage:(NSNumber *)page finishBlock:(dispatch_block_t)block;
- (NSArray<Floor *> *)cacheValueForTopicID:(NSNumber *)topicID withPage:(NSNumber *)page;
- (BOOL)hasCacheForTopicID:(NSNumber *)topicID withPage:(NSNumber *)page;
- (void)removeCacheForTopicID:(NSNumber *)topicID withPage:(NSNumber *)page;

- (Floor *)findFloorByID:(NSNumber *)floorID;

- (void)removeCacheLastUsedBeforeDate:(NSDate *)date;

- (void)saveMahjongFaceHistory:(NSMutableArray *)historyArray;
- (NSMutableArray *)mahjongFaceHistory;

@end

NS_ASSUME_NONNULL_END
