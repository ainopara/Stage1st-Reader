//
//  S1Tracer.h
//  Stage1st
//
//  Created by Suen Gabriel on 3/3/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S1Tracer : NSObject

@property (nonatomic, copy) NSString *identifyKey;
@property (nonatomic, copy) NSString *timeStampKey;

- (id)initWithTracerName:(NSString *)name;

- (void)hasViewed:(id)object;

- (NSArray *)recentViewedObjects;

- (id)objectInRecentForKey:(NSString *)key;

@end
