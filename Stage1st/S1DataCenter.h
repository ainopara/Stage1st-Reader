//
//  S1DataCenter.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
@class S1Tracer;
@interface S1DataCenter : NSObject

@property (strong, nonatomic) S1Tracer *tracer;

//For topic list View Controller
- (BOOL)hasCacheForKey:(NSString *)keyID;

- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;

- (void)loadNextPageForKey:(NSString *)keyID success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;

- (NSArray *)historyTopics;
- (void)removeTopicFromHistory:(NSNumber *)topicID;

- (NSArray *)favoriteTopics;
- (void)setTopicFavoriteState:(NSNumber *)topicID withState:(BOOL)state;

//About Network
- (void)cancelRequest;

@end
