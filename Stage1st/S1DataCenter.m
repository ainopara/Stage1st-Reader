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
@property (strong, nonatomic) S1Tracer *tracer;
@property (strong, nonatomic) NSMutableDictionary *cache;
@property (strong, nonatomic) NSMutableDictionary *cachePageNumber;

@end

@implementation S1DataCenter

-(instancetype)init {
    self = [super init];
    self.networkManager = [[S1NetworkManager alloc] init];
    self.tracer = [[S1Tracer alloc] init];
    self.cache = [[NSMutableDictionary alloc] init];
    self.cachePageNumber = [[NSMutableDictionary alloc] init];
    return self;
}

- (BOOL)hasCacheForKey:(NSString *)keyID {
    return self.cache[keyID] != nil;
}

- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    if (refresh || self.cache[keyID] == nil) {
        [self fetchTopicsForKeyFromServer:keyID withPage:1 success:^(NSArray *topicList) {
            success(topicList);
        } failure:^(NSError *error) {
            failure(error);
        }];
    } else {
        success(self.cache[keyID]);
    }
}

- (void)loadNextPageForKey:(NSString *)keyID success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    if (self.cachePageNumber[keyID] == nil) { return; }
    NSNumber *currentPageNumber = self.cachePageNumber[keyID];
    NSNumber *nextPageNumber = [NSNumber numberWithInteger:[currentPageNumber integerValue] + 1];
    [self fetchTopicsForKeyFromServer:keyID withPage:[nextPageNumber unsignedIntegerValue] success:^(NSArray *topicList) {
        success(topicList);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)fetchTopicsForKeyFromServer:(NSString *)keyID withPage:(NSUInteger)page success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure
{
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
                    for (S1Topic *compareTopic in self.cache[keyID]) {
                        if ([topic.topicID isEqualToNumber:compareTopic.topicID]) {
                            NSLog(@"Remove duplicate topic: %@", topic.title);
                            [self.cache[keyID] removeObject:compareTopic];
                            break;
                        }
                    }
                }
                
            }
            
            if (topics.count > 0) {
                if (page == 1) {
                    self.cache[keyID] = topics;
                    self.cachePageNumber[keyID] = @1;
                } else {
                    self.cache[keyID] = [[self.cache[keyID] arrayByAddingObjectsFromArray:topics] mutableCopy];
                    self.cachePageNumber[keyID] = [[NSNumber alloc] initWithInteger:page];
                }
            } else {
                if(page == 1) {
                    self.cache[keyID] = [[NSMutableArray alloc] init];
                    self.cachePageNumber[keyID] = @1;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                success(self.cache[keyID]);
            });
        });
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

@end
