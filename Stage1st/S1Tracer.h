//
//  S1Tracer.h
//  Stage1st
//
//  Created by Suen Gabriel on 3/3/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FMDatabase;
@class S1Topic;
typedef enum {
    S1TopicOrderByFavoriteSetDate,
    S1TopicOrderByLastVisitDate
} S1TopicOrderType;

@interface S1Tracer : NSObject

@property (nonatomic, strong) FMDatabase *db;

- (id)init;

- (void)hasViewed:(S1Topic *)topic;
- (void)removeTopicFromHistory:(NSNumber *)topic_id;

- (NSMutableArray *)historyObjectsWithSearchWord:(NSString *)searchWord;
- (NSMutableArray *)favoritedObjects:(S1TopicOrderType)order;

- (S1Topic *)tracedTopic:(NSNumber *)key;

- (BOOL)topicIsFavorited:(NSNumber *)topic_id;
- (void)setTopicFavoriteState:(NSNumber *)topic_id withState:(BOOL)state;

+ (void)migrateTracerToDatabase;
+ (void)upgradeDatabase;

@end
