//
//  DDErrorLevelFormatter.m
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

#import "DDErrorLevelFormatter.h"

@implementation DDErrorLevelFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
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
        logLevel = @"Tracing";        
    }

    return [NSString stringWithFormat:@"|%@| %@", logLevel, logMessage->_message];
}

@end
