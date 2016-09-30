//
//  S1YapDatabaseAdapter.h
//  Stage1st
//
//  Created by Zheng Li on 8/8/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "S1DataCenter.h"

@class DatabaseManager;

@interface S1YapDatabaseAdapter : NSObject<S1Backend>

@property (nonatomic, strong) DatabaseManager *database;

@end
