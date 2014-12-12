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
@property (strong, nonatomic) NSMutableDictionary *topicListCachePageNumber;

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
                NSMutableArray *topics = [S1Parser topicsFromAPI:responseDict];
                
                for (S1Topic *topic in topics) {
                    
                    //append tracer message to topics
                    S1Topic *tempTopic = [strongMyself.tracer tracedTopic:topic.topicID];
                    if (tempTopic) {
                        [topic addDataFromTracedTopic:tempTopic];
                    }
                    
                    // remove duplicate topics
                    if ([page integerValue] > 1) {
                        for (S1Topic *compareTopic in strongMyself.topicListCache[keyID]) {
                            if ([topic.topicID isEqualToNumber:compareTopic.topicID]) {
                                NSLog(@"Remove duplicate topic: %@", topic.title);
                                [strongMyself.topicListCache[keyID] removeObject:compareTopic];
                                break;
                            }
                        }
                    }
                    
                }
                
                if (topics.count > 0) {
                    if ([page isEqualToNumber:@1]) {
                        strongMyself.topicListCache[keyID] = topics;
                        strongMyself.topicListCachePageNumber[keyID] = @1;
                    } else {
                        strongMyself.topicListCache[keyID] = [[strongMyself.topicListCache[keyID] arrayByAddingObjectsFromArray:topics] mutableCopy];
                        strongMyself.topicListCachePageNumber[keyID] = page;
                    }
                } else {
                    if([page isEqualToNumber:@1]) {
                        strongMyself.topicListCache[keyID] = [[NSMutableArray alloc] init];
                        strongMyself.topicListCachePageNumber[keyID] = @1;
                    }
                }
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
                //check login state
                NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                [[NSUserDefaults standardUserDefaults] setValue:[S1Parser loginUserName:HTMLString] forKey:@"InLoginStateID"];
                
                //parse topics
                NSMutableArray *topics = [[S1Parser topicsFromHTMLData:responseObject withContext:@{@"FID": keyID}] mutableCopy];
                
                for (S1Topic *topic in topics) {
                    //append tracer message to topics
                    S1Topic *tempTopic = [strongMyself.tracer tracedTopic:topic.topicID];
                    if (tempTopic) {
                        [topic addDataFromTracedTopic:tempTopic];
                    }
                    
                    // remove duplicate topics
                    if ([page integerValue] > 1) {
                        for (S1Topic *compareTopic in strongMyself.topicListCache[keyID]) {
                            if ([topic.topicID isEqualToNumber:compareTopic.topicID]) {
                                NSLog(@"Remove duplicate topic: %@", topic.title);
                                [strongMyself.topicListCache[keyID] removeObject:compareTopic];
                                break;
                            }
                        }
                    }
                    
                }
                
                if (topics.count > 0) {
                    if ([page isEqualToNumber:@1]) {
                        strongMyself.topicListCache[keyID] = topics;
                        strongMyself.topicListCachePageNumber[keyID] = @1;
                    } else {
                        strongMyself.topicListCache[keyID] = [[strongMyself.topicListCache[keyID] arrayByAddingObjectsFromArray:topics] mutableCopy];
                        strongMyself.topicListCachePageNumber[keyID] = page;
                    }
                } else {
                    if([page isEqualToNumber:@1]) {
                        strongMyself.topicListCache[keyID] = [[NSMutableArray alloc] init];
                        strongMyself.topicListCachePageNumber[keyID] = @1;
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(strongMyself.topicListCache[keyID]);
                });
            });
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            failure(error);
        }];
    }
}

#pragma mark - Network (Content)

- (void)floorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    NSDate *start = [NSDate date];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UseAPI"]) {
        [S1NetworkManager requestTopicContentAPIForID:topic.topicID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
            NSTimeInterval timeInterval = [start timeIntervalSinceNow];
            NSLog(@"Finish Fetch:%f",-timeInterval);
            NSDictionary *responseDict = responseObject;
            //Update Topic
            topic.title = responseDict[@"Variables"][@"thread"][@"subject"];
            topic.authorUserID = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"thread"][@"authorid"] integerValue]];
            topic.authorUserName = responseDict[@"Variables"][@"thread"][@"author"];
            topic.formhash = responseDict[@"Variables"][@"formhash"];
            topic.replyCount = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"thread"][@"replies"] integerValue]];
            double postPerPage = [responseDict[@"Variables"][@"ppp"] doubleValue];
            topic.totalPageCount = [NSNumber numberWithDouble: ceil( [topic.replyCount doubleValue] / postPerPage )];
            
            NSArray *floorList = [S1Parser contentsFromAPI:responseDict];
            success(floorList);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            failure(error);
        }];
    } else {
        [S1NetworkManager requestTopicContentForID:topic.topicID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
            NSTimeInterval timeInterval = [start timeIntervalSinceNow];
            NSLog(@"Finish Fetch:%f",-timeInterval);
            //update title
            NSString *title = [S1Parser extractTopicTitle:responseObject];
            if (title != nil) {
                topic.title = title;
            }
            // get formhash
            NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            [topic setFormhash:[S1Parser formhashFromPage:HTMLString]];
            
            //set reply count
            if ([page isEqualToNumber:@1]) {
                NSInteger parsedReplyCount = [S1Parser replyCountFromThreadString:HTMLString];
                if (parsedReplyCount != 0) {
                    [topic setReplyCount:[NSNumber numberWithInteger:parsedReplyCount]];
                }
            }
            
            // update total page
            NSInteger parsedTotalPages = [S1Parser totalPagesFromThreadString:HTMLString];
            if (parsedTotalPages != 0) {
                [topic setTotalPageCount:[NSNumber numberWithInteger:parsedTotalPages]];
            }
            
            //check login state
            [[NSUserDefaults standardUserDefaults] setValue:[S1Parser loginUserName:HTMLString] forKey:@"InLoginStateID"];
            
            NSArray *floorList = [S1Parser contentsFromHTMLData:responseObject];
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
            BOOL appendSuffix = [[NSUserDefaults standardUserDefaults] boolForKey:@"AppendSuffix"];
            NSString *suffix = appendSuffix ? @"\n\n——— 来自[url=http://itunes.apple.com/us/app/stage1st-reader/id509916119?mt=8]Stage1st Reader For iOS[/url]" : @"";
            NSString *replyWithSuffix = [text stringByAppendingString:suffix];
            [params setObject:replyWithSuffix forKey:@"message"];
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
    BOOL appendSuffix = [[NSUserDefaults standardUserDefaults] boolForKey:@"AppendSuffix"];
    NSString *suffix = appendSuffix ? @"\n\n——— 来自[url=http://itunes.apple.com/us/app/stage1st-reader/id509916119?mt=8]Stage1st Reader For iOS[/url]" : @"";
    NSString *replyWithSuffix = [text stringByAppendingString:suffix];
    NSDictionary *params = @{@"posttime":timestamp,
                             @"formhash":topic.formhash,
                             @"usesig":@"1",
                             @"subject":@"",
                             @"message":replyWithSuffix};
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
        self.cachedHistoryTopics = [self.tracer historyObjectsWithLeftCallback:^(NSMutableArray *leftTopics) {
            //update search filter
            NSArray *fullTopics = [self.cachedHistoryTopics arrayByAddingObjectsFromArray:leftTopics];
            IMQuickSearchFilter *filter = [IMQuickSearchFilter filterWithSearchArray:fullTopics keys:@[@"title"]];
            self.historySearch = [[IMQuickSearch alloc] initWithFilters:@[filter]];
            self.cachedHistoryTopics = fullTopics;
            //return full data.
            if ([searchWord isEqualToString:@""]) {
                leftTopicsHandler(fullTopics);
            } else {
                NSMutableArray *fullResult = [[self.historySearch filteredObjectsWithValue:searchWord] mutableCopy];
                [fullResult sortUsingDescriptors:@[self.sortDescriptor]];
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
    return [self.tracer tracedTopic:topicID];
}
#pragma mark - Cache
- (void)clearTopicListCache {
    //self.topicListCache = [[NSMutableDictionary alloc] init];
    //self.topicListCachePageNumber = [[NSMutableDictionary alloc] init];
}
@end
