//
//  S1SettingViewController.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/13/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "GSStaticTableViewController.h"

@interface S1SettingViewController : GSStaticTableViewController

@property (nonatomic, copy) void (^completionHandler)(BOOL needToUpdate);

@end
