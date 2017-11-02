//
//  GSSingleSelectionTableViewController.h
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 2/11/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import "GSStaticTableViewController.h"

@interface GSSingleSelectionTableViewController : GSStaticTableViewController

@property (nonatomic, copy) void (^completionHandler)(NSString *selectedKey);

- (id)initWithKeys:(NSArray *)keys andSelectedKey:(NSString *)selectedKey;

@end
