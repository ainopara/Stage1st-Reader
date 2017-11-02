//
//  GSReorderableTableViewController.h
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 2/10/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import "GSStaticTableViewController.h"

@interface GSReorderableTableViewController : GSStaticTableViewController

@property (nonatomic, copy) void (^completionHandler)(NSArray *keys);


/*
 Format:
 @[ @[ key1, key2 ],
    @[ key3, key4, key5],
    ...
  ]
 */

- (id)initWithKeys:(NSArray *)keys;

@end
