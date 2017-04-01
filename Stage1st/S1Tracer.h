//
//  S1Tracer.h
//  Stage1st
//
//  Created by Suen Gabriel on 3/3/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//


@class FMDatabase;

@interface S1Tracer : NSObject

@property (nonatomic, strong) FMDatabase *db;

+ (void)upgradeDatabase;
+ (void)migrateToYapDatabase;

@end
