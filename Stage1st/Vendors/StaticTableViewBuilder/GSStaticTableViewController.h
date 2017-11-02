//
//  GSStaticTableViewController.h
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 1/26/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GSSection.h"
#import "GSRow.h"

@class GSSection;

@interface GSStaticTableViewController : UITableViewController

@property (nonatomic, strong) NSMutableArray *sections;

- (void)addSection:(void (^)(GSSection *section))continuation;

@end
