//
//  GSSection.h
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 1/26/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GSRow;

@interface GSSection : NSObject

@property (nonatomic, strong) NSMutableArray *rows;

- (void)addRow:(void (^)(GSRow *row))continuation;

- (NSInteger)numberOfRows;

- (GSRow *)rowOfIndex:(NSInteger)index;

@end
