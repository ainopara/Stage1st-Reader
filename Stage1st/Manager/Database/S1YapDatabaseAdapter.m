//
//  S1YapDatabaseAdapter.m
//  Stage1st
//
//  Created by Zheng Li on 8/8/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <YapDatabase/YapDatabase.h>

#import "S1YapDatabaseAdapter.h"
#import "DatabaseManager.h"
#import <YapDatabase/YapDatabaseQuery.h>
#import <YapDatabase/YapDatabaseFullTextSearchTransaction.h>
#import "S1Topic.h"

NS_ASSUME_NONNULL_BEGIN

@interface S1YapDatabaseAdapter ()

@property (nonatomic, strong) DatabaseManager *database;

@end

@implementation S1YapDatabaseAdapter

- (instancetype)initWithDatabase:(DatabaseManager *)database {
    self = [super init];
    if (self != nil) {
        _database = database;
    }
    return self;
}

@end

@implementation S1YapDatabaseAdapter (Topic)

- (void)hasViewed:(S1Topic *)topic {
    [self.database.bgDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        S1Topic *tracedTopic = [transaction objectForKey:[topic.topicID stringValue] inCollection:Collection_Topics];
        if (tracedTopic == nil) {
            DDLogDebug(@"[Database] Save Topic: \n%@",topic);
            S1Topic *topicCopy = [topic copy]; // do not change topic's value since it's shared with topiclist view controller.
            topicCopy.lastReplyCount = nil;
            [transaction setObject:topicCopy forKey:[topicCopy.topicID stringValue] inCollection:Collection_Topics];
        } else {
            tracedTopic = [tracedTopic copy]; // make mutable

            if (topic.title != nil && (tracedTopic.title == nil || (tracedTopic.title != nil && (![tracedTopic.title isEqualToString:topic.title])))) {
                tracedTopic.title = topic.title;
            }
            if (topic.fID != nil && (tracedTopic.fID == nil || (tracedTopic.fID != nil && (![tracedTopic.fID isEqualToNumber:topic.fID])))) {
                tracedTopic.fID = topic.fID;
            }
            if (topic.authorUserID != nil && (tracedTopic.authorUserID == nil || (tracedTopic.authorUserID != nil && (![tracedTopic.authorUserID isEqualToNumber:topic.authorUserID])))) {
                tracedTopic.authorUserID = topic.authorUserID;
            }
            if (topic.replyCount != nil && (tracedTopic.replyCount == nil || (tracedTopic.replyCount != nil && (![tracedTopic.replyCount isEqualToNumber:topic.replyCount])))) {
                tracedTopic.replyCount = topic.replyCount;
            }
            if (topic.lastViewedPage != nil && (tracedTopic.lastViewedPage == nil || (tracedTopic.lastViewedPage != nil && (![tracedTopic.lastViewedPage isEqualToNumber:topic.lastViewedPage])))) {
                tracedTopic.lastViewedPage = topic.lastViewedPage;
            }
            if (topic.lastViewedPosition != nil && (tracedTopic.lastViewedPosition == nil || (tracedTopic.lastViewedPosition != nil && (![tracedTopic.lastViewedPosition isEqualToNumber:topic.lastViewedPosition])))) {
                tracedTopic.lastViewedPosition = topic.lastViewedPosition;
            }
            if (topic.favorite != nil && (tracedTopic.favorite == nil || (tracedTopic.favorite != nil && (![tracedTopic.favorite isEqualToNumber:topic.favorite])))) {
                tracedTopic.favorite = topic.favorite;
            }
            if (topic.favoriteDate != nil && (tracedTopic.favoriteDate == nil || (tracedTopic.favoriteDate != nil && (![tracedTopic.favoriteDate isEqualToDate:topic.favoriteDate])))) {
                tracedTopic.favoriteDate = topic.favoriteDate;
            }
            tracedTopic.lastReplyCount = nil;
            tracedTopic.lastViewedDate = [NSDate date];
            DDLogDebug(@"[Database] Update Topic: \n%@",tracedTopic);
            [transaction setObject:tracedTopic forKey:[tracedTopic.topicID stringValue] inCollection:Collection_Topics];
        }
    }];
}

- (void)removeTopicFromHistory:(NSNumber *)topicID {
    [self.database.bgDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction removeObjectForKey:[topicID stringValue] inCollection:Collection_Topics];
    }];
}

- (void)removeTopicFromFavorite:(NSNumber *)topicID {
    [self.database.bgDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        S1Topic *topic = [[transaction objectForKey:[topicID stringValue] inCollection:Collection_Topics] copy];
        topic.favorite = [NSNumber numberWithBool:NO];
        [transaction replaceObject:topic forKey:[topicID stringValue] inCollection:Collection_Topics];
    }];
}

- (S1Topic *_Nullable)topicByID:(NSNumber *)topicID {
    __block S1Topic *topic = nil;
    [self.database.bgDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        topic = [transaction objectForKey:[topicID stringValue] inCollection:Collection_Topics];
    }];
    return topic;
}

- (NSNumber *)numberOfTopicsInDatabse {
    __block NSUInteger count = 0;
    [self.database.bgDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        count = [transaction numberOfKeysInCollection:Collection_Topics];
    }];
    return @(count);
}

- (NSNumber *)numberOfFavoriteTopicsInDatabse {
    __block NSUInteger count = 0;
    [self.database.bgDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [[transaction ext:Ext_FullTextSearch_Archive] enumerateKeysMatching:@"favorite:FY title:*" usingBlock:^(NSString *collection, NSString *key, BOOL *stop) {
            count = count + 1;
        }];
    }];
    return @(count);
}

- (void)removeTopicBeforeDate:(NSDate *)date {
    [self.database.bgDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
        __block NSMutableArray *keysToRemove = [[NSMutableArray alloc] init];
        [transaction enumerateKeysAndObjectsInCollection:Collection_Topics usingBlock:^(NSString * _Nonnull key, id  _Nonnull object, BOOL * _Nonnull stop) {
            S1Topic *topic = object;
            NSDate *lastUsedDate = topic.lastViewedDate;
            BOOL favorite = [topic.favorite boolValue];
            if ((!favorite) && date && lastUsedDate && [date timeIntervalSinceDate:lastUsedDate] > 0) {
                [keysToRemove addObject:key];
            }
        }];
        DDLogDebug(@"%lu keys removed from topic history",(unsigned long)[keysToRemove count]);
        for (NSString *key in keysToRemove) {
            [transaction removeObjectForKey:key inCollection:Collection_Topics];
        }
    }];
}

@end

@implementation S1YapDatabaseAdapter (User)

- (void)blockUserWithID:(NSInteger)userID {
    NSString *userIDKey = [NSString stringWithFormat:@"%lu", (unsigned long)userID];
    [self.database.bgDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        NSDictionary<NSString *, id> *info = @{ @"Date" : [NSDate date] };
        [transaction setObject:info forKey:userIDKey inCollection:Collection_UserBlackList];
    }];
}

- (void)unblockUserWithID:(NSInteger)userID {
    NSString *userIDKey = [NSString stringWithFormat:@"%lu", (unsigned long)userID];
    [self.database.bgDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        [transaction removeObjectForKey:userIDKey inCollection:Collection_UserBlackList];
    }];
}

- (BOOL)userIDIsBlocked:(NSInteger)userID {
    NSString *userIDKey = [NSString stringWithFormat:@"%lu", (unsigned long)userID];
    __block BOOL userIsBlocked = NO;
    [self.database.bgDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        userIsBlocked = [transaction hasObjectForKey:userIDKey inCollection:Collection_UserBlackList];
    }];
    return userIsBlocked;
}

@end

NS_ASSUME_NONNULL_END
