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
#import "YapDatabase.h"
#import "S1YapDatabaseAdapter.h"
#import "S1CacheDatabaseManager.h"

@interface S1DataCenter ()

@property (strong, nonatomic) id<S1Backend> tracer;

@property (strong, nonatomic) NSString *formhash;

@property (strong, nonatomic) NSMutableDictionary *topicListCache;
@property (strong, nonatomic) NSMutableDictionary *topicListCachePageNumber;
@property (strong, nonatomic) NSMutableDictionary *cacheFinishHandlers;

@property (strong, nonatomic) NSArray *cachedHistoryTopics;
@property (strong, nonatomic) IMQuickSearch *historySearch;
@property (strong, nonatomic) IMQuickSearch *favoriteSearch;
@property (strong, nonatomic) NSSortDescriptor *sortDescriptor;

@end


@implementation S1DataCenter

-(instancetype)init {
    self = [super init];
    
    _tracer = [[S1YapDatabaseAdapter alloc] init];
    _topicListCache = [[NSMutableDictionary alloc] init];
    _topicListCachePageNumber = [[NSMutableDictionary alloc] init];
    _cacheFinishHandlers = [NSMutableDictionary dictionary];
    //_shouldInterruptHistoryCallback = NO;
    _sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"lastViewedDate" ascending:NO comparator:^NSComparisonResult(id obj1, id obj2) {
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

+ (S1DataCenter *)sharedDataCenter
{
    static S1DataCenter *dataCenter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dataCenter = [[S1DataCenter alloc] init];
    });
    return dataCenter;
}



#pragma mark - Network (Topic List)

- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    if (refresh || self.topicListCache[keyID] == nil) {
        [self fetchTopicsForKeyFromServer:keyID withPage:@1 success:success failure:failure];
    } else {
        success(self.topicListCache[keyID]);
    }
}

- (void)loadNextPageForKey:(NSString *)keyID success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    
    if (self.topicListCachePageNumber[keyID] == nil) {
        failure(nil);
        return;
    }
    
    NSNumber *currentPageNumber = self.topicListCachePageNumber[keyID];
    NSNumber *nextPageNumber = [NSNumber numberWithInteger:[currentPageNumber integerValue] + 1];
    [self fetchTopicsForKeyFromServer:keyID withPage:nextPageNumber success:success failure:failure];
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
                
                success(strongMyself.topicListCache[keyID]);
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
            S1Topic *tempTopic = [strongMyself tracedTopic:topic.topicID];
            if (tempTopic) {
                [topic addDataFromTracedTopic:tempTopic];
            }
        }
        success(topics);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

#pragma mark - Network (Content Cache)
- (BOOL)hasPrecacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page {
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    return [[S1CacheDatabaseManager sharedInstance] hasCacheForKey:key inCollection:Collection_TopicFloors];
}

- (void)precacheFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page shouldUpdate:(BOOL)shouldUpdate {
    NSLog(@"Precache:%@-%@ begin.", topic.topicID, page);
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    if ((shouldUpdate == NO) && ([[S1CacheDatabaseManager sharedInstance] hasCacheForKey:key inCollection:Collection_TopicFloors])) {
        NSLog(@"Precache:%@-%@ canceled.", topic.topicID, page);
        return;
    }
    void (^failureHandler)(NSURLSessionDataTask *task, NSError *error) = ^(NSURLSessionDataTask *task, NSError *error) {
        [self.cacheFinishHandlers setValue:nil forKey:key];
        NSLog(@"Precache:%@-%@ failed.", topic.topicID, page);
    };
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
            [[S1CacheDatabaseManager sharedInstance] setCacheValue:floorList forKey:key inCollection:Collection_TopicFloors];
            [self callFinishHandlerIfExistForKey:key withResult:floorList];
            NSLog(@"Precache:%@-%@ finish.", topic.topicID, page);
        } failure:failureHandler];
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
            [[S1CacheDatabaseManager sharedInstance] setCacheValue:floorList forKey:key inCollection:Collection_TopicFloors];
            [self callFinishHandlerIfExistForKey:key withResult:floorList];
            NSLog(@"Precache:%@-%@ finish.", topic.topicID, page);
        } failure:failureHandler];
    }
}
- (void)removePrecachedFloorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page {
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    [[S1CacheDatabaseManager sharedInstance] removeCacheForKey:key inCollection:Collection_TopicFloors];
}

- (void)setFinishHandlerForTopic:(S1Topic *)topic withPage:(NSNumber *)page andHandler:(void (^)(NSArray *floorList))handler {
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    [self.cacheFinishHandlers setValue:handler forKey:key];
}

- (void)callFinishHandlerIfExistForKey:(NSString *)key withResult:(NSArray *)floorList {
    //call finish block if exist
    void (^handler)(NSArray *floorList) = [self.cacheFinishHandlers valueForKey:key];
    if (handler != nil) {
        [self.cacheFinishHandlers setValue:nil forKey:key];
        handler(floorList);
    }
}

#pragma mark - Network (Content)
- (void)floorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    // Use Cache Result If Exist
    NSString *key = [NSString stringWithFormat:@"%@:%@", topic.topicID, page];
    NSArray *floorList = [[S1CacheDatabaseManager sharedInstance] cacheValueForKey:key inCollection:Collection_TopicFloors];
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
            [[S1CacheDatabaseManager sharedInstance] setCacheValue:floorList forKey:key inCollection:Collection_TopicFloors];
            
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
            [[S1CacheDatabaseManager sharedInstance] setCacheValue:floorList forKey:key inCollection:Collection_TopicFloors];
            
            success(floorList);
            
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            failure(error);
        }];
    }
    
}

- (void)replySpecificFloor:(S1Floor *)floor inTopic:(S1Topic *)topic atPage:(NSNumber *)page withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure {
    [S1NetworkManager requestReplyRefereanceContentForTopicID:topic.topicID withPage:page floorID:floor.floorID forumID:topic.fID success:^(NSURLSessionDataTask *task, id responseObject) {
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
    NSDictionary *params = @{@"posttime":timestamp,
                             @"formhash":topic.formhash,
                             @"usesig":@"1",
                             @"subject":@"",
                             @"message":text};
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

- (void)setTopicFavoriteState:(NSNumber *)topicID withState:(BOOL)state {
    [self.tracer setTopicFavoriteState:topicID withState:state];
}

- (S1Topic *)tracedTopic:(NSNumber *)topicID {
    return [self.tracer tracedTopicByID:topicID];
}

- (void)handleDatabaseImport:(NSURL *)databaseURL {
    //[self.tracer syncWithDatabasePath:[databaseURL absoluteString]];
}



#pragma mark - Topic List Cache

- (BOOL)hasCacheForKey:(NSString *)keyID {
    return self.topicListCache[keyID] != nil;
}

- (void)clearTopicListCache {
    self.topicListCache = [[NSMutableDictionary alloc] init];
    self.topicListCachePageNumber = [[NSMutableDictionary alloc] init];
}

#pragma mark - Helper
- (void)processTopics:(NSMutableArray *)topics withKeyID:(NSString *)keyID andPage:(NSNumber *)page {
    NSMutableArray *processedTopics = [[NSMutableArray alloc] init];
    for (S1Topic *topic in topics) {
        
        //append tracer message to topics
        S1Topic *tempTopic = [self tracedTopic:topic.topicID];
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
