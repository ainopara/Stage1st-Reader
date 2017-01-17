//
//  DDErrorLevelFormatter.h
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CocoaLumberjack.DDLog;

@interface DDErrorLevelFormatter : NSObject <DDLogFormatter>

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end
