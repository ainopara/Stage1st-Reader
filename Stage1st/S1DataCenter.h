//
//  S1DataCenter.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@class S1Tracer;
@class S1Topic;
@class S1Floor;

@interface S1DataCenter : NSObject

+ (S1DataCenter *)sharedDataCenter;

//For topic list View Controller
- (BOOL)hasCacheForKey:(NSString *)keyID;

- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;

- (void)loadNextPageForKey:(NSString *)keyID success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;

- (BOOL)canMakeSearchRequest;

- (void)searchTopicsForKeyword:(NSString *)keyword success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;

//For Content View Controller
- (BOOL)hasPrecacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page;

- (void)precacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page shouldUpdate:(BOOL)shouldUpdate;

- (void)removePrecachedFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page;

- (void)setFinishHandlerForTopic:(S1Topic *)topic withPage:(NSNumber *)page andHandler:(void (^)(NSArray *floorList))handler;

- (void)floorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page success:(void (^)(NSArray *floorList))success failure:(void (^)(NSError *error))failure;
- (S1Floor *)searchFloorInCacheByFloorID:(NSNumber *)floorID;
// Reply
- (void)replySpecificFloor:(S1Floor *)floor inTopic:(S1Topic *)topic atPage:(NSNumber *)page withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure;
- (void)replyTopic:(S1Topic *)topic withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure;

- (void)findTopicFloor:(NSNumber *)floorID inTopicID:(NSNumber *)topicID success:(void (^)())success failure:(void (^)(NSError *))failure;

//Database

- (void)hasViewed:(S1Topic *)topic;
- (void)removeTopicFromHistory:(NSNumber *)topicID;
- (void)removeTopicFromFavorite:(NSNumber *)topicID;

- (S1Topic *)tracedTopic:(NSNumber *)topicID;
- (NSNumber *)numberOfTopics;
- (NSNumber *)numberOfFavorite;

//About Network
- (void)cancelRequest;

- (void)clearTopicListCache;

- (void)cleaning;

// Mahjong Face
@property (strong, nonatomic) NSMutableArray *mahjongFaceHistoryArray;
@end

@protocol S1Backend <NSObject>

- (void)hasViewed:(S1Topic *)topic;
- (void)removeTopicFromHistory:(NSNumber *)topicID;
- (void)removeTopicFromFavorite:(NSNumber *)topicID;
- (S1Topic *)topicByID:(NSNumber *)topicID;
- (NSNumber *)numberOfTopicsInDatabse;
- (NSNumber *)numberOfFavoriteTopicsInDatabse;
@end
