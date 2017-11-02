//
//  GSRow.h
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 1/26/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GSRow : NSObject

@property (nonatomic, copy) void (^configurationBlock)(UITableViewCell *cell);
@property (nonatomic, copy) void (^eventHandlerBlock)(UITableViewCell *cell);

@end
