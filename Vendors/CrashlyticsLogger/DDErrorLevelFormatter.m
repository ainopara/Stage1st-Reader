//
//  DDErrorLevelFormatter.m
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

#import "DDErrorLevelFormatter.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DDErrorLevelFormatter

- (NSString *_Nullable)formatLogMessage:(DDLogMessage *)logMessage {
    NSString *logLevel;
    if (logMessage->_context != 1024) {
        switch (logMessage->_flag) {
            case DDLogFlagError    : logLevel = @"Error  "; break;
            case DDLogFlagWarning  : logLevel = @"Warning"; break;
            case DDLogFlagInfo     : logLevel = @"Info   "; break;
            case DDLogFlagDebug    : logLevel = @"Debug  "; break;
            default                : logLevel = @"Verbose"; break;
        }
    } else {
        logLevel = @"Tracing"; // Use `Tracing` rather than `Tracking` to limit to 7 characters.
    }

    return [NSString stringWithFormat:@"|%@| %@", logLevel, logMessage->_message];
}

@end

@implementation DDSimpleDispatchQueueLogFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    NSString *queueThreadLabel = [self queueThreadLabelForLogMessage:logMessage];
    return [NSString stringWithFormat:@"@%@ %@", queueThreadLabel, logMessage->_message];
}

@end

@implementation DDSimpleDateLogFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    NSString *timestamp = [self stringFromDate:(logMessage->_timestamp)];
    return [NSString stringWithFormat:@"%@ %@", timestamp, logMessage->_message];
}

@end

NS_ASSUME_NONNULL_END
