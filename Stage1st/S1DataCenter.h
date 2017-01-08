//
//  S1DataCenter.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class S1Tracer;
@class S1Topic;
@class Floor;
@class MahjongFaceItem;

@interface S1DataCenter : NSObject

+ (S1DataCenter *)sharedDataCenter;

// Mahjong Face
@property (strong, nonatomic) NSArray<MahjongFaceItem *> *mahjongFaceHistoryArray;

// For topic list View Controller
- (BOOL)hasCacheForKey:(NSString *)keyID;

- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray<S1Topic *> *topicList))success failure:(void (^)(NSError *error))failure;

- (void)loadNextPageForKey:(NSString *)keyID success:(void (^)(NSArray<S1Topic *> *topicList))success failure:(void (^)(NSError *error))failure;

- (BOOL)canMakeSearchRequest;

- (void)searchTopicsForKeyword:(NSString *)keyword success:(void (^)(NSArray<S1Topic *> *topicList))success failure:(void (^)(NSError *error))failure;

// For Content View Controller
- (BOOL)hasPrecacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page;

- (void)precacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page shouldUpdate:(BOOL)shouldUpdate;

- (void)removePrecachedFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page;

- (void)floorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page success:(void (^)(NSArray<Floor *> *floorList, BOOL fromCache))success failure:(void (^)(NSError *error))failure;
- (Floor *)searchFloorInCacheByFloorID:(NSNumber *)floorID;

// Reply
- (void)replySpecificFloor:(Floor *)floor inTopic:(S1Topic *)topic atPage:(NSNumber *)page withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure;
- (void)replyTopic:(S1Topic *)topic withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure;

- (void)findTopicFloor:(NSNumber *)floorID inTopicID:(NSNumber *)topicID success:(void (^)())success failure:(void (^)(NSError *))failure;

// Database

- (void)hasViewed:(S1Topic *)topic;
- (void)removeTopicFromHistory:(NSNumber *)topicID;
- (void)removeTopicFromFavorite:(NSNumber *)topicID;

- (S1Topic * _Nullable)tracedTopic:(NSNumber *)topicID;
- (NSNumber *)numberOfTopics;
- (NSNumber *)numberOfFavorite;

// About Network
- (void)cancelRequest;

// Cleaning
- (void)clearTopicListCache;
- (void)cleaning;

@end

@protocol S1Backend <NSObject>

- (void)hasViewed:(S1Topic *)topic;
- (void)removeTopicFromHistory:(NSNumber *)topicID;
- (void)removeTopicFromFavorite:(NSNumber *)topicID;
- (S1Topic * _Nullable)topicByID:(NSNumber *)topicID;
- (NSNumber *)numberOfTopicsInDatabse;
- (NSNumber *)numberOfFavoriteTopicsInDatabse;
- (void)removeTopicBeforeDate:(NSDate *)date;

@end

NS_ASSUME_NONNULL_END
