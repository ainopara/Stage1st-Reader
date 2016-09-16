//
//  S1CacheDatabaseManager.m
//  Stage1st
//
//  Created by Zheng Li on 8/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1CacheDatabaseManager.h"
#import "YapDatabase.h"

NSString *const Collection_TopicFloors = @"topicFloors";
NSString *const Collection_FloorIDs = @"floorIDs";
NSString *const Collection_MahjongFace = @"mahjongFace";
NSString *const Metadata_LastUsed = @"lastUsed";

@interface S1CacheDatabaseManager ()

@property (strong, nonatomic) YapDatabase *cacheDatabase;
@property (strong, nonatomic) YapDatabaseConnection *cacheConnection;
@property (strong, nonatomic) YapDatabaseConnection *backgroundCacheConnection;

@end

@implementation S1CacheDatabaseManager

- (instancetype)init {
    self = [super init];
    _cacheDatabase = [[YapDatabase alloc] initWithPath:self.cacheURL.absoluteString];
    _cacheConnection = [_cacheDatabase newConnection];
    _backgroundCacheConnection = [_cacheDatabase newConnection];
    return self;
}

+ (S1CacheDatabaseManager *)sharedInstance {
    static S1CacheDatabaseManager *cacheDatabaseManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheDatabaseManager = [[S1CacheDatabaseManager alloc] init];
    });
    return cacheDatabaseManager;
}

- (NSURL *)cacheURL {
    NSURL *documentsDirectory = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    return [documentsDirectory URLByAppendingPathComponent:@"Cache.sqlite"];
}

#pragma mark - Batch Floor Cache

- (void)setFloorArray:(NSArray<Floor *> *)floors inTopicID:(NSNumber *)topicID ofPage:(NSNumber *)page finishBlock:(dispatch_block_t)block {
    NSString *key = [self keyForTopicID:topicID page:page];
    [self.backgroundCacheConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [floors enumerateObjectsUsingBlock:^(Floor *floor, NSUInteger idx, BOOL *stop) {
            [transaction setObject:key forKey: [[NSNumber numberWithInteger:floor.ID] stringValue] inCollection:Collection_FloorIDs];
        }];
        [transaction setObject:floors forKey:key inCollection:Collection_TopicFloors withMetadata:@{Metadata_LastUsed:[NSDate date]}];
    } completionBlock:block];
}

- (NSArray<Floor *> *)cacheValueForTopicID:(NSNumber *)topicID withPage:(NSNumber *)page {
    __block NSArray *result = nil;
    NSString *key = [self keyForTopicID:topicID page:page];
    [self.cacheConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        result = [transaction objectForKey:key inCollection:Collection_TopicFloors];
    }];
    [self.backgroundCacheConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
        NSDictionary *metaData = [transaction metadataForKey:key inCollection:Collection_TopicFloors];
        if (metaData) {
            NSMutableDictionary *mutableMetaData = [metaData mutableCopy];
            [mutableMetaData setValue:[NSDate date] forKey:Metadata_LastUsed];
            [transaction replaceMetadata:mutableMetaData forKey:key inCollection:Collection_TopicFloors];
        }
    }];
    return result;
}

- (BOOL)hasCacheForTopicID:(NSNumber *)topicID withPage:(NSNumber *)page {
    __block BOOL hasCache = NO;
    NSString *key = [self keyForTopicID:topicID page:page];
    [self.cacheConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        hasCache = [transaction hasObjectForKey:key inCollection:Collection_TopicFloors];
    }];
    //NSLog(@"%@, %d",key, hasCache);
    return hasCache;
}

- (void)removeCacheForTopicID:(NSNumber *)topicID withPage:(NSNumber *)page {
    NSString *key = [self keyForTopicID:topicID page:page];
    [self.backgroundCacheConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
        [transaction removeObjectForKey:key inCollection:Collection_TopicFloors];
    }];
}

#pragma mark - Single Floor Operation

- (Floor *)findFloorByID:(NSNumber *)floorID {
    NSString *floorIDString = [floorID stringValue];
    __block Floor *result = nil;
    [self.cacheConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSString *key = [transaction objectForKey:floorIDString inCollection:Collection_FloorIDs];
        if (key) {
            NSArray *floors = [transaction objectForKey:key inCollection:Collection_TopicFloors];
            if (floors) {
                __block Floor *theResult = nil;
                [floors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    Floor *floor = obj;
                    if (floor.ID == floorID.integerValue) {
                        theResult = floor;
                        *stop = YES;
                    }
                }];
                result = theResult;
            }
        }
        
    }];
    return result;
}

#pragma mark - Cleaning

- (void)removeCacheLastUsedBeforeDate:(NSDate *)date {
    [self.backgroundCacheConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        __block NSMutableArray *keysToRemove = [[NSMutableArray alloc] init];
        [transaction enumerateKeysAndMetadataInCollection:Collection_TopicFloors usingBlock:^(NSString *key, id metadata, BOOL *stop) {
            NSDictionary *metaDataDict = metadata;
            NSDate *lastUsedDate = [metaDataDict valueForKey:Metadata_LastUsed];
            if (date && lastUsedDate && [date timeIntervalSinceDate:lastUsedDate] > 0) {
                [keysToRemove addObject:key];
            }
        }];

        DDLogInfo(@"Keys to remove from floor cache: %@", keysToRemove);
        for (NSString *key in keysToRemove) {
            [transaction removeObjectForKey:key inCollection:Collection_TopicFloors];
        }
    }];
}

#pragma mark - Mahjong Face History

- (void)saveMahjongFaceHistory:(NSMutableArray *)historyArray {
    [self.backgroundCacheConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction setObject:historyArray forKey:@"history" inCollection:Collection_MahjongFace];
    }];
}

- (NSMutableArray *)mahjongFaceHistory {
    __block NSMutableArray *historyArray = nil;
    [self.cacheConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        historyArray = [transaction objectForKey:@"history" inCollection:Collection_MahjongFace];
    }];
    return historyArray;
}

#pragma mark - Key

- (NSString *)keyForTopicID:(NSNumber *)topicID page:(NSNumber *)page {
    return [NSString stringWithFormat:@"%@:%@", topicID, page];
}

@end
