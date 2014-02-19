//
//  S1Tracer.h
//  Stage1st
//
//  Created by Suen Gabriel on 3/3/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FMDatabase;

@interface S1Tracer : NSObject

@property (nonatomic, strong) FMDatabase *db;

- (id)init;

- (void)hasViewed:(id)object;
- (void)removeTopicFromHistory:(NSNumber *)topic_id;

- (NSArray *)recentViewedObjects;
- (NSArray *)favoritedObjects;

- (id)tracedTopic:(NSNumber *)key;

- (BOOL)topicIsFavorited:(NSNumber *)topic_id;
- (void)setTopicFavoriteState:(NSNumber *)topic_id withState:(BOOL)state;

+ (void)migrateTracerToDatabase;

@end
