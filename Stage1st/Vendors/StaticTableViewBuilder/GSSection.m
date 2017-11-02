//
//  GSSection.m
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 1/26/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import "GSSection.h"
#import "GSRow.h"

@interface GSSection()


@end

@implementation GSSection

- (id)init
{
    self = [super init];
    if (!self)  return nil;
    _rows = [NSMutableArray array];
    return self;
}

- (void)addRow:(void (^)(GSRow *))continuation
{
    GSRow *row = [[GSRow alloc] init];
    [self.rows addObject:row];
    continuation(row);
}

- (NSInteger)numberOfRows
{
    return [self.rows count];
}

- (GSRow *)rowOfIndex:(NSInteger)index
{
    return self.rows[index];
}


@end
