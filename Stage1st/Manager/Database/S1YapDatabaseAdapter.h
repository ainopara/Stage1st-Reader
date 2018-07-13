//
//  S1YapDatabaseAdapter.h
//  Stage1st
//
//  Created by Zheng Li on 8/8/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DatabaseManager;
@class S1Topic;

NS_ASSUME_NONNULL_BEGIN

@interface S1YapDatabaseAdapter : NSObject

- (instancetype)initWithDatabase:(DatabaseManager *)database;

@end

@interface S1YapDatabaseAdapter (Topic)

- (void)hasViewed:(S1Topic *)topic;
- (void)removeTopicFromHistory:(NSNumber *)topicID;
- (void)removeTopicFromFavorite:(NSNumber *)topicID;
- (S1Topic * _Nullable)topicByID:(NSNumber *)topicID;
- (NSNumber *)numberOfTopicsInDatabse;
- (NSNumber *)numberOfFavoriteTopicsInDatabse;
- (void)removeTopicBeforeDate:(NSDate *)date;

@end

@interface S1YapDatabaseAdapter (User)

- (void)blockUserWithID:(NSInteger)userID;
- (void)unblockUserWithID:(NSInteger)userID;
- (BOOL)userIDIsBlocked:(NSInteger)userID;

@end

NS_ASSUME_NONNULL_END
