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

@property (nonatomic, copy) NSString *identifyKey;
@property (nonatomic, copy) NSString *timeStampKey;
@property (nonatomic, strong) FMDatabase *db;

- (id)initWithTracerName:(NSString *)name;

- (void)hasViewed:(id)object;

- (NSArray *)recentViewedObjects;

- (id)tracedTopic:(NSNumber *)key;

- (BOOL)topicIsFavorited:(NSNumber *)topic_id;

@end
