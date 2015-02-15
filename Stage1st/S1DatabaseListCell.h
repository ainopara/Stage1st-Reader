//
//  S1DatabaseListCell.h
//  Stage1st
//
//  Created by Zheng Li on 12/28/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface S1DatabaseListCell : UITableViewCell
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong) NSString *databaseName;
@property (nonatomic, strong) NSURL *databasePath;
@end
