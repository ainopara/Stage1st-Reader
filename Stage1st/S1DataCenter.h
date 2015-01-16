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

@property (strong, nonatomic) S1Tracer *tracer;
@property (assign, nonatomic) BOOL shouldReloadHistoryCache;
@property (assign, nonatomic) BOOL shouldReloadFavoriteCache;
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

- (void)floorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page success:(void (^)(NSArray *floorList))success failure:(void (^)(NSError *error))failure;

- (void)replySpecificFloor:(S1Floor *)floor inTopic:(S1Topic *)topic atPage:(NSNumber *)page withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure;

- (void)replyTopic:(S1Topic *)topic withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure;

//Database
- (NSMutableArray *)historyTopicsWithSearchWord:(NSString *)searchWord andLeftCallback:(void (^)(NSArray *))leftTopicsHandler;
- (void)hasViewed:(S1Topic *)topic;
- (void)removeTopicFromHistory:(NSNumber *)topicID;

- (NSMutableArray *)favoriteTopicsWithSearchWord:(NSString *)searchWord;
- (BOOL)topicIsFavorited:(NSNumber *)topicID;
- (void)setTopicFavoriteState:(NSNumber *)topicID withState:(BOOL)state;

- (S1Topic *)tracedTopic:(NSNumber *)topicID;

- (void)handleDatabaseImport:(NSURL *)databaseURL;

//About Network
- (void)cancelRequest;

- (void)clearTopicListCache;

- (void)clearContentPageCache;
@end
