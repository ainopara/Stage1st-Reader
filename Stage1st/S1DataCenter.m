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

@interface S1DataCenter ()

@property (strong, nonatomic) S1NetworkManager *networkManager;

@property (strong, nonatomic) NSMutableDictionary *topicListCache;
@property (strong, nonatomic) NSMutableDictionary *topicListCachePageNumber;

@end

@implementation S1DataCenter

-(instancetype)init {
    self = [super init];
    self.networkManager = [[S1NetworkManager alloc] init];
    self.tracer = [[S1Tracer alloc] init];
    self.topicListCache = [[NSMutableDictionary alloc] init];
    self.topicListCachePageNumber = [[NSMutableDictionary alloc] init];
    return self;
}

- (BOOL)hasCacheForKey:(NSString *)keyID {
    return self.topicListCache[keyID] != nil;
}

#pragma mark - Network (Topic List)

- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    if (refresh || self.topicListCache[keyID] == nil) {
        [self fetchTopicsForKeyFromServer:keyID withPage:1 success:^(NSArray *topicList) {
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
    [self fetchTopicsForKeyFromServer:keyID withPage:[nextPageNumber unsignedIntegerValue] success:^(NSArray *topicList) {
        success(topicList);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)fetchTopicsForKeyFromServer:(NSString *)keyID withPage:(NSUInteger)page success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure {
    [self.networkManager requestTopicListForKey:keyID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //check login state
            NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            [[NSUserDefaults standardUserDefaults] setValue:[S1Parser loginUserName:HTMLString] forKey:@"InLoginStateID"];
            
            //parse topics
            NSMutableArray *topics = [[S1Parser topicsFromHTMLData:responseObject withContext:@{@"FID": keyID}] mutableCopy];
            
            for (S1Topic *topic in topics) {
                
                //append tracer message to topics
                S1Topic *tempTopic = [self.tracer tracedTopic:topic.topicID];
                if (tempTopic) {
                    [topic setLastReplyCount:tempTopic.replyCount];
                    [topic setLastViewedPage:tempTopic.lastViewedPage];
                    [topic setLastViewedPosition:tempTopic.lastViewedPosition];
                    [topic setVisitCount:tempTopic.visitCount];
                    [topic setFavorite:tempTopic.favorite];
                }
                
                // remove duplicate topics
                if (page > 1) {
                    for (S1Topic *compareTopic in self.topicListCache[keyID]) {
                        if ([topic.topicID isEqualToNumber:compareTopic.topicID]) {
                            NSLog(@"Remove duplicate topic: %@", topic.title);
                            [self.topicListCache[keyID] removeObject:compareTopic];
                            break;
                        }
                    }
                }
                
            }
            
            if (topics.count > 0) {
                if (page == 1) {
                    self.topicListCache[keyID] = topics;
                    self.topicListCachePageNumber[keyID] = @1;
                } else {
                    self.topicListCache[keyID] = [[self.topicListCache[keyID] arrayByAddingObjectsFromArray:topics] mutableCopy];
                    self.topicListCachePageNumber[keyID] = [[NSNumber alloc] initWithInteger:page];
                }
            } else {
                if(page == 1) {
                    self.topicListCache[keyID] = [[NSMutableArray alloc] init];
                    self.topicListCachePageNumber[keyID] = @1;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                success(self.topicListCache[keyID]);
            });
        });
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

#pragma mark - Network (Content)

- (void)floorsForTopicID:(NSNumber *)topicID withPage:(NSUInteger)page success:(void (^)(NSArray *, S1Topic *))success failure:(void (^)(NSError *))failure {
    [self.networkManager requestTopicContentForID:topicID withPage:page success:^(NSURLSessionDataTask *task, id responseObject) {
        S1Topic *topic = [[S1Topic alloc] init];
        NSArray *floorList = [S1Parser contentsFromHTMLData:responseObject withOffset:page];
        
        // get formhash
        NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        [topic setFormhash:[S1Parser formhashFromThreadString:HTMLString]];
        
        //set reply count
        if (page == 1) {
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
        
        success(floorList, topic);
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}


- (void)cancelRequest {
    [self.networkManager cancelRequest];
}


#pragma mark - Database

- (NSArray *)historyTopics {
    return [[self.tracer historyObjects] mutableCopy];
}

- (void)removeTopicFromHistory:(NSNumber *)topicID {
    [self.tracer removeTopicFromHistory:topicID];
}


- (NSArray *)favoriteTopics {
    return [self.tracer favoritedObjects:S1TopicOrderByLastVisitDate];
}

- (void)setTopicFavoriteState:(NSNumber *)topicID withState:(BOOL)state {
    [self.tracer setTopicFavoriteState:topicID withState:state];
}

- (void)clearTopicListCache {
    //self.topicListCache = [[NSMutableDictionary alloc] init];
    //self.topicListCachePageNumber = [[NSMutableDictionary alloc] init];
}
@end
