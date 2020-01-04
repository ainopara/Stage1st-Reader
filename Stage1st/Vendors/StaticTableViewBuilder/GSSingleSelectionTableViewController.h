//
//  GSSingleSelectionTableViewController.h
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 2/11/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import "GSStaticTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface GSSingleSelectionTableViewController : GSStaticTableViewController

@property (nonatomic, copy) void (^completionHandler)(NSString *selectedKey);

- (id)initWithKeys:(NSArray<NSString *> *)keys andSelectedKey:(NSString *)selectedKey;

@end

NS_ASSUME_NONNULL_END
