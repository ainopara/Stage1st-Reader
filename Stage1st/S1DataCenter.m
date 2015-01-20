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
#import "S1Floor.h"
#import "IMQuickSearch.h"

@interface S1DataCenter ()

@property (strong, nonatomic) NSMutableDictionary *topicListCache;
@property (strong, nonatomic) NSString *formhash;
@property (strong, nonatomic) NSMutableDictionary *topicListCachePageNumber;

@property (strong, nonatomic) NSMutableDictionary *floorCache;
@property (strong, nonatomic) NSMutableDictionary *cacheFinishHandlers;

@property (strong, nonatomic) NSArray *cachedHistoryTopics;
@property (strong, nonatomic) IMQuickSearch *historySearch;
@property (strong, nonatomic) IMQuickSearch *favoriteSearch;
@property (strong, nonatomic) NSSortDescriptor *sortDescriptor;

@end


@implementation S1DataCenter

-(instancetype)init {
    self = [super init];
    self.tracer = [[S1Tracer alloc] init];
    self.topicListCache = [[NSMutableDictionary alloc] init];
    self.topicListCachePageNumber = [[NSMutableDictionary alloc] init];
    self.floorCache = [NSMutableDictionary dictionary];
    self.cacheFinishHandlers = [NSMutableDictionary dictionary];
    self.shouldReloadFavoriteCache = YES;
    self.shouldReloadHistoryCache = YES;
    self.sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"lastViewedDate" ascending:NO comparator:^NSComparisonResult(id obj1, id obj2) {
        if ([obj1 timeIntervalSince1970] > [obj2 timeIntervalSince1970]) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        
        if ([obj1 timeIntervalSince1970] < [obj2 timeIntervalSince1970]) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    
    return self;
}

- (BOOL)hasCacheForKey:(NSString *)keyID {
    return self.topicListCache[keyID] != nil;
}

#pragma mark - Network (Topic List)

- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    if (refresh || self.topicListCache[keyID] == nil) {
        [self fetchTopicsForKeyFromServer:keyID withPage:@1 success:^(NSArray *topicList) {
            success(topicList);
        } failure:^(NSError *error) {
            failure(error);
        }];
    } else {
        success(self.topicListCache[keyID]);
    }
}

- (void)loadNextPageForKey:(NSString *)keyID success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    if (self.topicListCachePageNumber[keyID] == nil) { return; }
    NSNumber *currentPageNumber = self.topicListCachePageNumber[keyID];
    NSNumber *nextPageNumber = [NSNumber numberWithInteger:[currentPageNumber integerValue] + 1];
    [self fetchTopicsForKeyFromServer:keyID withPage:nextPageNumber success:^(NSArray *topicList) {
        success(topicList);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)fetchTopicsForKeyFromServer:(NSString *)keyID withPage:(NSNumber *)page success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure {
    __weak typeof(self) myself = self;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UseAPI"]) {
        [S1NetworkManager requestTopicListAPIForKey:keyID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                __strong typeof(self) strongMyself = myself;
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
                    strongMyself.formhash = formhash;
                }
                //get topics
                NSMutableArray *topics = [S1Parser topicsFromAPI:responseDict];
                
                [strongMyself processTopics:topics withKeyID:keyID andPage:page];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(strongMyself.topicListCache[keyID]);
                });
            });
            
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            failure(error);
        }];
    } else {
        [S1NetworkManager requestTopicListForKey:keyID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                __strong typeof(self) strongMyself = myself;
                NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                
                //check login state
                [[NSUserDefaults standardUserDefaults] setValue:[S1Parser loginUserName:HTMLString] forKey:@"InLoginStateID"];
                
                //pick formhash
                NSString *formhash = [S1Parser formhashFromPage:HTMLString];
                if (formhash != nil) {
                    strongMyself.formhash = formhash;
                }
                
                //parse topics
                NSMutableArray *topics = [[S1Parser topicsFromHTMLData:responseObject withContext:@{@"FID": keyID}] mutableCopy];
                
                [strongMyself processTopics:topics withKeyID:keyID andPage:page];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(strongMyself.topicListCache[keyID]);
                });
            });
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            failure(error);
        }];
    }
}

- (BOOL)canMakeSearchRequest {
    return self.formhash == nil ? NO : YES;
}

- (void)searchTopicsForKeyword:(NSString *)keyword success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    __weak typeof(self) myself = self;
    [S1NetworkManager postSearchForKeyword:keyword andFormhash:self.formhash success:^(NSURLSessionDataTask *task, id responseObject) {
        __strong typeof(self) strongMyself = myself;
        //parse topics
        NSArray *topics = [S1Parser topicsFromSearchResultHTMLData:responseObject];
        
        //append tracer message to topics
        for (S1Topic *topic in topics) {
            S1Topic *tempTopic = [strongMyself.tracer tracedTopicByID:topic.topicID];
            if (tempTopic) {
                [topic addDataFromTracedTopic:tempTopic];
            }
            topic.highlight = keyword;
        }
        
        success(topics);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

#pragma mark - Network (Content Cache)
- (BOOL)hasPrecacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page {
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    return [self.floorCache valueForKey:key] != nil;
}
- (void)precacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page shouldUpdate:(BOOL)shouldUpdate {//TODO: weak self
    NSLog(@"Precache:%@-%@ begin.", topic.topicID, page);
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    if ((shouldUpdate == NO) && ([self.floorCache valueForKey:key] != nil)) {
        NSLog(@"Precache:%@-%@ cancel.", topic.topicID, page);
        return;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UseAPI"]) {
        [S1NetworkManager requestTopicContentAPIForID:topic.topicID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
            
            //Update Topic
            NSDictionary *responseDict = responseObject;
            [topic updateFromTopic:[S1Parser topicInfoFromAPI:responseDict]];
            
            //Check Login State
            NSString *loginUsername = responseDict[@"Variables"][@"member_username"];
            if ([loginUsername isEqualToString:@""]) {
                loginUsername = nil;
            }
            [[NSUserDefaults standardUserDefaults] setValue:loginUsername forKey:@"InLoginStateID"];
            //get floors
            NSArray *floorList = [S1Parser contentsFromAPI:responseDict];
            //update floor cache
            if ([self.floorCache valueForKey:key] != nil) {
                [self.floorCache removeObjectForKey:key];
            }
            [self.floorCache addEntriesFromDictionary:@{key: floorList}];
            //call finish block if exist
            void (^handler)(NSArray *floorList) = [self.cacheFinishHandlers valueForKey:key];
            if (handler != nil) {
                handler(floorList);
            }
            NSLog(@"Precache:%@-%@ finish.", topic.topicID, page);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"pre cache failed.");
        }];
    } else {
        [S1NetworkManager requestTopicContentForID:topic.topicID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
            
            //Update Topic
            [topic updateFromTopic:[S1Parser topicInfoFromThreadPage:responseObject andPage:page]];
            
            //check login state
            NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            [[NSUserDefaults standardUserDefaults] setValue:[S1Parser loginUserName:HTMLString] forKey:@"InLoginStateID"];
            //get floors
            NSArray *floorList = [S1Parser contentsFromHTMLData:responseObject];
            //update floor cache
            if ([self.floorCache valueForKey:key] != nil) {
                [self.floorCache removeObjectForKey:key];
            }
            [self.floorCache addEntriesFromDictionary:@{key: floorList}];
            //call finish block if exist
            void (^handler)(NSArray *floorList) = [self.cacheFinishHandlers valueForKey:key];
            if (handler != nil) {
                handler(floorList);
            }
            NSLog(@"Precache:%@-%@ finish.", topic.topicID, page);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"pre cache failed.");
        }];
    }
}
- (void)removePrecachedFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page {
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    if ([self.floorCache valueForKey:key] != nil) {
        [self.floorCache removeObjectForKey:key];
    }
}

- (void)setFinishHandlerForTopic:(S1Topic *)topic withPage:(NSNumber *)page andHandler:(void (^)(NSArray *floorList))handler {
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    [self.cacheFinishHandlers setValue:handler forKey:key];
}

#pragma mark - Network (Content)
- (void)floorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    // Use Cache Result
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    NSArray *floorList = [self.floorCache objectForKey:key];
    if (floorList) {
        success(floorList);
        return;
    }
    
    NSDate *start = [NSDate date];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UseAPI"]) {
        [S1NetworkManager requestTopicContentAPIForID:topic.topicID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
            NSTimeInterval timeInterval = [start timeIntervalSinceNow];
            NSLog(@"Finish Fetch:%f",-timeInterval);
            
            //Update Topic
            NSDictionary *responseDict = responseObject;
            [topic updateFromTopic:[S1Parser topicInfoFromAPI:responseDict]];
            
            //Check Login State
            NSString *loginUsername = responseDict[@"Variables"][@"member_username"];
            if ([loginUsername isEqualToString:@""]) {
                loginUsername = nil;
            }
            [[NSUserDefaults standardUserDefaults] setValue:loginUsername forKey:@"InLoginStateID"];
            //get floors
            NSArray *floorList = [S1Parser contentsFromAPI:responseDict];
            
            //update floor cache
            if ([self.floorCache valueForKey:key] != nil) {
                [self.floorCache removeObjectForKey:key];
            }
            [self.floorCache addEntriesFromDictionary:@{key: floorList}];
            
            success(floorList);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            failure(error);
        }];
    } else {
        [S1NetworkManager requestTopicContentForID:topic.topicID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
            NSTimeInterval timeInterval = [start timeIntervalSinceNow];
            NSLog(@"Finish Fetch:%f",-timeInterval);
            
            //Update Topic
            [topic updateFromTopic:[S1Parser topicInfoFromThreadPage:responseObject andPage:page]];
            
            //check login state
            NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            [[NSUserDefaults standardUserDefaults] setValue:[S1Parser loginUserName:HTMLString] forKey:@"InLoginStateID"];
            //get floors
            NSArray *floorList = [S1Parser contentsFromHTMLData:responseObject];
            
            //update floor cache
            if ([self.floorCache valueForKey:key] != nil) {
                [self.floorCache removeObjectForKey:key];
            }
            [self.floorCache addEntriesFromDictionary:@{key: floorList}];
            
            success(floorList);
            
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            failure(error);
        }];
    }
    
}

- (void)replySpecificFloor:(S1Floor *)floor inTopic:(S1Topic *)topic atPage:(NSNumber *)page withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure {
    [S1NetworkManager requestReplyRefereanceContentForTopicID:topic.topicID withPage:page floorID:floor.floorID fieldID:topic.fID success:^(NSURLSessionDataTask *task, id responseObject) {
        NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        NSMutableDictionary *params = [S1Parser replyFloorInfoFromResponseString:responseString];
        if ([params[@"requestSuccess"]  isEqual: @YES]) {
            [params removeObjectForKey:@"requestSuccess"];
            [params setObject:@"true" forKey:@"replysubmit"];
            [params setObject:text forKey:@"message"];
            [S1NetworkManager postReplyForTopicID:topic.topicID withPage:page fieldID:topic.fID andParams:[params copy] success:^(NSURLSessionDataTask *task, id responseObject) {
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
    NSDictionary *params = @{@"posttime":timestamp,
                             @"formhash":topic.formhash,
                             @"usesig":@"1",
                             @"subject":@"",
                             @"message":text};
    [S1NetworkManager postReplyForTopicID:topic.topicID fieldID:topic.fID andParams:params success:^(NSURLSessionDataTask *task, id responseObject) {
        success();
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

- (void)cancelRequest {
    [S1NetworkManager cancelRequest];
}


#pragma mark - Database

- (NSArray *)historyTopicsWithSearchWord:(NSString *)searchWord andLeftCallback:(void (^)(NSArray *))leftTopicsHandler {
    //filter process
    if (self.shouldReloadHistoryCache || self.historySearch == nil) {
        __weak typeof(self) myself = self;
        self.cachedHistoryTopics = [self.tracer historyObjectsWithLeftCallback:^(NSMutableArray *leftTopics) {
            __strong typeof(self) strongMyself = myself;
            //update search filter
            NSArray *fullTopics = [strongMyself.cachedHistoryTopics arrayByAddingObjectsFromArray:leftTopics];
            IMQuickSearchFilter *filter = [IMQuickSearchFilter filterWithSearchArray:fullTopics keys:@[@"title"]];
            strongMyself.historySearch = [[IMQuickSearch alloc] initWithFilters:@[filter]];
            strongMyself.cachedHistoryTopics = fullTopics;
            //return full data.
            if ([searchWord isEqualToString:@""]) {
                leftTopicsHandler(fullTopics);
            } else {
                NSMutableArray *fullResult = [[strongMyself.historySearch filteredObjectsWithValue:searchWord] mutableCopy];
                [fullResult sortUsingDescriptors:@[strongMyself.sortDescriptor]];
                leftTopicsHandler(fullResult);
            }
        }];
        //set search filter
        IMQuickSearchFilter *filter = [IMQuickSearchFilter filterWithSearchArray:self.cachedHistoryTopics keys:@[@"title"]];
        self.historySearch = [[IMQuickSearch alloc] initWithFilters:@[filter]];
        self.shouldReloadHistoryCache = NO;
    }
    //return parital data
    if ([searchWord isEqualToString:@""]) {
        return self.cachedHistoryTopics;
    } else {
        NSMutableArray *result = [[self.historySearch filteredObjectsWithValue:searchWord] mutableCopy];
        
        [result sortUsingDescriptors:@[self.sortDescriptor]];
        return result;
    }
}

- (NSArray *)favoriteTopicsWithSearchWord:(NSString *)searchWord {
    
    //filter process
    if (self.shouldReloadFavoriteCache) {
        NSMutableArray *topics = [self.tracer favoritedObjects];
        IMQuickSearchFilter *filter = [IMQuickSearchFilter filterWithSearchArray:topics keys:@[@"title"]];
        self.favoriteSearch = [[IMQuickSearch alloc] initWithFilters:@[filter]];
        self.shouldReloadFavoriteCache = NO;
    }
    NSMutableArray *result = [[self.favoriteSearch filteredObjectsWithValue:searchWord] mutableCopy];
    
    [result sortUsingDescriptors:@[self.sortDescriptor]];
    return result;
}

- (void)hasViewed:(S1Topic *)topic {
    [self.tracer hasViewed:topic];
}

- (void)removeTopicFromHistory:(NSNumber *)topicID {
    [self.tracer removeTopicFromHistory:topicID];
}

- (void)setTopicFavoriteState:(NSNumber *)topicID withState:(BOOL)state {
    [self.tracer setTopicFavoriteState:topicID withState:state];
}

- (BOOL)topicIsFavorited:(NSNumber *)topicID {
    return [self.tracer topicIsFavorited:topicID];
}

- (S1Topic *)tracedTopic:(NSNumber *)topicID {
    return [self.tracer tracedTopicByID:topicID];
}

- (void)handleDatabaseImport:(NSURL *)databaseURL {
    [self.tracer syncWithDatabasePath:[databaseURL absoluteString]];
}
#pragma mark - Cache
- (void)clearTopicListCache {
    //self.topicListCache = [[NSMutableDictionary alloc] init];
    //self.topicListCachePageNumber = [[NSMutableDictionary alloc] init];
}

- (void)clearContentPageCache {
    self.floorCache = [NSMutableDictionary dictionary];
}
#pragma mark - Helper
- (void)processTopics:(NSMutableArray *)topics withKeyID:(NSString *)keyID andPage:(NSNumber *)page {
    NSMutableArray *processedTopics = [[NSMutableArray alloc] init];
    for (S1Topic *topic in topics) {
        
        //append tracer message to topics
        S1Topic *tempTopic = [self.tracer tracedTopicByID:topic.topicID];
        if (tempTopic) {
            [topic addDataFromTracedTopic:tempTopic];
        }
        BOOL topicIsDuplicated = NO;
        // remove duplicate topics
        if ([page integerValue] > 1) {
            for (S1Topic *compareTopic in self.topicListCache[keyID]) {
                if ([topic.topicID isEqualToNumber:compareTopic.topicID]) {
                    NSLog(@"Remove duplicate topic: %@", topic.title);
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
