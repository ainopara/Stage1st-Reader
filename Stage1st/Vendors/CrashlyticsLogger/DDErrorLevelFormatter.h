//
//  DDErrorLevelFormatter.h
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CocoaLumberjack;

NS_ASSUME_NONNULL_BEGIN

@interface DDErrorLevelFormatter : NSObject <DDLogFormatter>

@end

@interface DDSimpleDispatchQueueLogFormatter: DDDispatchQueueLogFormatter

@end

@interface DDSimpleDateLogFormatter: DDDispatchQueueLogFormatter

@end

NS_ASSUME_NONNULL_END
