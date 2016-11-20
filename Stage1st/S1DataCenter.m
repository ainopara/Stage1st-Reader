//
//  S1DataCenter.m
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1DataCenter.h"
#import "S1NetworkManager.h"
#import "S1Topic.h"
#import "S1Tracer.h"
#import "S1Parser.h"
#import "YapDatabase.h"
#import "S1YapDatabaseAdapter.h"

@interface S1DataCenter ()

@property (strong, nonatomic) id<S1Backend> tracer;
@property (strong, nonatomic) CacheDatabaseManager *cacheDatabaseManager;
@property (strong, nonatomic) DiscuzAPIManager *apiManager;

@property (strong, nonatomic) NSString *formhash;

@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMutableArray<S1Topic *> *> *topicListCache;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSNumber *> *topicListCachePageNumber;

@end

@implementation S1DataCenter

- (instancetype)init {
    self = [super init];
    
    _tracer = [[S1YapDatabaseAdapter alloc] initWithDatabase:MyDatabaseManager];
    _topicListCache = [[NSMutableDictionary alloc] init];
    _topicListCachePageNumber = [[NSMutableDictionary alloc] init];

    NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:true error:NULL];
    NSString *cacheDatabasePath = [[[documentsDirectoryURL URLByAppendingPathComponent:@"Cache.sqlite"] filePathURL] path];
    _cacheDatabaseManager = [[CacheDatabaseManager alloc] initWithPath:cacheDatabasePath];

    return self;
}

+ (S1DataCenter *)sharedDataCenter {
    static S1DataCenter *dataCenter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dataCenter = [[S1DataCenter alloc] init];
    });
    return dataCenter;
}

#pragma mark - Network (Topic List)

- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray<S1Topic *> *))success failure:(void (^)(NSError *))failure {
    if (refresh || self.topicListCache[keyID] == nil) {
        [self fetchTopicsForKeyFromServer:keyID withPage:@1 success:success failure:failure];
    } else {
        success(self.topicListCache[keyID]);
    }
}

- (void)loadNextPageForKey:(NSString *)keyID success:(void (^)(NSArray<S1Topic *> *))success failure:(void (^)(NSError *))failure {
    
    if (self.topicListCachePageNumber[keyID] == nil) {
        failure(nil);
        return;
    }
    
    NSNumber *currentPageNumber = self.topicListCachePageNumber[keyID];
    NSNumber *nextPageNumber = [NSNumber numberWithInteger:[currentPageNumber integerValue] + 1];
    [self fetchTopicsForKeyFromServer:keyID withPage:nextPageNumber success:success failure:failure];
}

- (void)fetchTopicsForKeyFromServer:(NSString *)keyID withPage:(NSNumber *)page success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure {
    __weak __typeof__(self) weakSelf = self;
    [S1NetworkManager requestTopicListAPIForKey:keyID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong __typeof__(self) strongSelf = weakSelf;
            NSDictionary *responseDict = responseObject;

            //check login state
            NSString *loginUsername = responseDict[@"Variables"][@"member_username"];
            if ([loginUsername isEqualToString:@""]) {
                loginUsername = nil;
            }
            [[NSUserDefaults standardUserDefaults] setValue:loginUsername forKey:@"InLoginStateID"];

            //pick formhash
            NSString *formhash = responseDict[@"Variables"][@"formhash"];
            if (formhash != nil) {
                strongSelf.formhash = formhash;
            }
            //get topics
            NSMutableArray *topics = [S1Parser topicsFromAPI:responseDict];

            [strongSelf processAndCacheTopics:topics withKeyID:keyID andPage:page];

            success(strongSelf.topicListCache[keyID]);
        });

    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

- (BOOL)canMakeSearchRequest {
    return self.formhash == nil ? NO : YES;
}

- (void)searchTopicsForKeyword:(NSString *)keyword success:(void (^)(NSArray<S1Topic *> *))success failure:(void (^)(NSError *))failure {
    __weak __typeof__(self) myself = self;
    [S1NetworkManager postSearchForKeyword:keyword andFormhash:self.formhash success:^(NSURLSessionDataTask *task, id responseObject) {
        __strong __typeof__(self) strongMyself = myself;
        //parse topics
        NSArray<S1Topic *> *topics = [S1Parser topicsFromSearchResultHTMLData:responseObject];

        NSMutableArray<S1Topic *> *processedTopics = [[NSMutableArray<S1Topic *> alloc] init];
        
        //append tracer message to topics
        for (S1Topic *topic in topics) {
            S1Topic *tracedTopic = [[strongMyself tracedTopic:topic.topicID] copy];
            if (tracedTopic) {
                [tracedTopic update:topic];
                [processedTopics addObject:tracedTopic];
            } else {
                [processedTopics addObject:topic];
            }
        }
        success(processedTopics);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

#pragma mark - Network (Content Cache)

- (BOOL)hasPrecacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page {
    return [self.cacheDatabaseManager hasFloorsIn:[topic.topicID integerValue] page:[page integerValue]];
}

- (void)precacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page shouldUpdate:(BOOL)shouldUpdate {
    DDLogVerbose(@"[Network] Precache %@-%@ begin", topic.topicID, page);

    if (shouldUpdate == NO && [self hasPrecacheFloorsForTopic:topic withPage:page]) {
        DDLogVerbose(@"[Database] Precache %@-%@ hit", topic.topicID, page);
        return;
    }

    [S1NetworkManager requestTopicContentAPIForID:topic.topicID withPage:page success:^(NSURLSessionDataTask *task, NSDictionary *responseDict) {
        // Update Topic
        S1Topic *extractedTopicInfo = [S1Parser topicInfoFromAPI:responseDict];
        if (extractedTopicInfo != nil) {
            [topic update:extractedTopicInfo];
        } else {
            DDLogWarn(@"[Network] Can not ectract valid topic info from dict %@", responseDict);
        }

        // Update Login State
        NSString *loginUsername = responseDict[@"Variables"][@"member_username"];
        if ([loginUsername isEqualToString:@""]) {
            loginUsername = nil;
        }
        [[NSUserDefaults standardUserDefaults] setValue:loginUsername forKey:@"InLoginStateID"];

        // Get floors
        NSArray *floorList = [S1Parser contentsFromAPI:responseDict];

        // Update floor cache
        if (floorList && [floorList count] > 0) {
            [self.cacheDatabaseManager setWithFloors:floorList topicID:[topic.topicID integerValue] page:[page integerValue] completion:^{
                DDLogDebug(@"[Network] Precache %@-%@ finish", topic.topicID, page);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"S1FloorDidCached" object:nil userInfo:@{@"topicID": topic.topicID, @"page": page}];
            }];
        } else {
            DDLogError(@"[Network] Precache %@-%@ failed (no floor list)", topic.topicID, page);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        DDLogWarn(@"[Network] Precache %@-%@ failed", topic.topicID, page);
    }];
}

- (void)removePrecachedFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page {
    [self.cacheDatabaseManager removeFloorsIn:[topic.topicID integerValue] page:[page integerValue]];
}

- (Floor *)searchFloorInCacheByFloorID:(NSNumber *)floorID {
    return [self.cacheDatabaseManager floorWithID:[floorID integerValue]];
}

#pragma mark - Network (Content)

- (void)floorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page success:(void (^)(NSArray<Floor *> *, BOOL))success failure:(void (^)(NSError *))failure {
    NSParameterAssert(![topic isImmutable]);
    // Use Cache Result If Exist
    NSArray *floorList = [self.cacheDatabaseManager floorsIn:[topic.topicID integerValue] page:[page integerValue]];
    if (floorList && [floorList count] > 0) {
        success(floorList, YES);
        return;
    }
    
    NSDate *start = [NSDate date];
    [S1NetworkManager requestTopicContentAPIForID:topic.topicID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
        NSTimeInterval timeInterval = [start timeIntervalSinceNow];
        DDLogDebug(@"[Network] Content Finish Fetch:%f", -timeInterval);

        //Update Topic
        NSDictionary *responseDict = responseObject;
        S1Topic *topicFromPageResponse = [S1Parser topicInfoFromAPI:responseDict];
        if (topicFromPageResponse != nil) {
            [topic update:topicFromPageResponse];
        }

        //Check Login State
        NSString *loginUsername = responseDict[@"Variables"][@"member_username"];
        if ([loginUsername isEqualToString:@""]) {
            loginUsername = nil;
        }
        [[NSUserDefaults standardUserDefaults] setValue:loginUsername forKey:@"InLoginStateID"];
        //get floors
        NSArray *floorList = [S1Parser contentsFromAPI:responseDict];

        //update floor cache
        if (floorList && [floorList count] > 0) {
            [self.cacheDatabaseManager setWithFloors:floorList topicID:[topic.topicID integerValue] page:[page integerValue] completion:^{
                success(floorList, NO);
            }];
        } else {
            failure([[NSError alloc] initWithDomain:@"Stage1stErrorDomain" code:10 userInfo:nil]);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

- (void)replySpecificFloor:(Floor *)floor inTopic:(S1Topic *)topic atPage:(NSNumber *)page withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure {
    [S1NetworkManager requestReplyRefereanceContentForTopicID:topic.topicID withPage:page floorID:[NSNumber numberWithInteger:floor.ID] forumID:topic.fID success:^(NSURLSessionDataTask *task, id responseObject) {
        NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        NSMutableDictionary *params = [S1Parser replyFloorInfoFromResponseString:responseString];
        if ([params[@"requestSuccess"]  isEqual: @YES]) {
            [params removeObjectForKey:@"requestSuccess"];
            [params setObject:@"true" forKey:@"replysubmit"];
            [params setObject:text forKey:@"message"];
            [S1NetworkManager postReplyForTopicID:topic.topicID withPage:page forumID:topic.fID andParams:[params copy] success:^(NSURLSessionDataTask *task, id responseObject) {
                success();
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                failure(error);
            }];
        } else {
            NSError *error = [[NSError alloc] init];
            failure(error);
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

- (void)replyTopic:(S1Topic *)topic withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *))failure {
    NSString *timestamp = [NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970])];
    NSDictionary *params = @{
        @"posttime":timestamp,
        @"formhash":topic.formhash,
        @"usesig":@"1",
        @"subject":@"",
        @"message":text
    };
    [S1NetworkManager postReplyForTopicID:topic.topicID forumID:topic.fID andParams:params success:^(NSURLSessionDataTask *task, id responseObject) {
        success();
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

- (void)findTopicFloor:(NSNumber *)floorID inTopicID:(NSNumber *)topicID success:(void (^)())success failure:(void (^)(NSError *))failure {
    [S1NetworkManager findTopicFloor:floorID inTopicID:topicID success:^(NSURLSessionDataTask *task, id responseObject) {
        success();
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

- (void)cancelRequest {
    [S1NetworkManager cancelRequest];
}

#pragma mark - Database

- (void)hasViewed:(S1Topic *)topic {
    [self.tracer hasViewed:topic];
}

- (void)removeTopicFromHistory:(NSNumber *)topicID {
    [self.tracer removeTopicFromHistory:topicID];
}

- (void)removeTopicFromFavorite:(NSNumber *)topicID {
    [self.tracer removeTopicFromFavorite:topicID];
}

- (S1Topic *)tracedTopic:(NSNumber *)topicID {
    return [self.tracer topicByID:topicID];
}

- (NSNumber *)numberOfTopics {
    return [self.tracer numberOfTopicsInDatabse];
}

- (NSNumber *)numberOfFavorite {
    return [self.tracer numberOfFavoriteTopicsInDatabse];
}

#pragma mark - Topic List Cache

- (BOOL)hasCacheForKey:(NSString *)keyID {
    return self.topicListCache[keyID] != nil;
}

- (void)clearTopicListCache {
    self.topicListCache = [[NSMutableDictionary alloc] init];
    self.topicListCachePageNumber = [[NSMutableDictionary alloc] init];
}

#pragma mark - Cleaning

- (void)cleaning {
    [self.cacheDatabaseManager removeFloorsWithLastUsedBefore:[NSDate dateWithTimeIntervalSinceNow:-2 * 7 * 24 * 3600]];
    [self.cacheDatabaseManager cleanInvalidFloorsID];
    NSTimeInterval duration = [[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"] doubleValue];
    if (duration < 0) {
        return;
    }
    [self.tracer removeTopicBeforeDate:[NSDate dateWithTimeIntervalSinceNow:-duration]];
}

#pragma mark - Mahjongface History

- (NSArray<MahjongFaceItem *> *)mahjongFaceHistoryArray {
    return [self.cacheDatabaseManager mahjongFaceHistory];
}

- (void)setMahjongFaceHistoryArray:(NSArray<MahjongFaceItem *> *)mahjongFaceHistoryArray {
    [self.cacheDatabaseManager setWithMahjongFaceHistory:mahjongFaceHistoryArray];
}

#pragma mark - Helper

- (void)processAndCacheTopics:(NSMutableArray *)topics withKeyID:(NSString *)keyID andPage:(NSNumber *)page {
    NSMutableArray<S1Topic *> *processedTopics = [[NSMutableArray alloc] init];

    // Append tracer message to topics
    for (S1Topic *topic in topics) {
        BOOL topicIsDuplicated = NO;
        // remove duplicate topics
        if ([page integerValue] > 1) {
            for (S1Topic *compareTopic in self.topicListCache[keyID]) {
                if ([topic.topicID isEqualToNumber:compareTopic.topicID]) {
                    DDLogDebug(@"[DataCenter] Remove duplicate topic: %@", topic.title);
                    NSInteger index = [self.topicListCache[keyID] indexOfObject:compareTopic];
                    [self.topicListCache[keyID] replaceObjectAtIndex:index withObject:topic];
                    topicIsDuplicated = YES;
                    break;
                }
            }
        }
        if (!topicIsDuplicated) {
            [processedTopics addObject:topic];
        }
    }

    // Cache topic list
    if (topics.count > 0) {
        if ([page isEqualToNumber:@1]) {
            self.topicListCache[keyID] = processedTopics;
            self.topicListCachePageNumber[keyID] = @1;
        } else {
            self.topicListCache[keyID] = [[self.topicListCache[keyID] arrayByAddingObjectsFromArray:processedTopics] mutableCopy];
            self.topicListCachePageNumber[keyID] = page;
        }
    } else {
        if([page isEqualToNumber:@1]) {
            self.topicListCache[keyID] = [[NSMutableArray alloc] init];
            self.topicListCachePageNumber[keyID] = @1;
        }
    }
}

@end
