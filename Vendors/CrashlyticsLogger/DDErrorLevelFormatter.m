//
//  DDErrorLevelFormatter.m
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

#import "DDErrorLevelFormatter.h"

@implementation DDErrorLevelFormatter

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss:SSS"];
    }
    return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    NSString *logLevel;
    switch (logMessage->_flag) {
        case DDLogFlagError    : logLevel = @"*Error**"; break;
        case DDLogFlagWarning  : logLevel = @"*Warning*"; break;
        case DDLogFlagInfo     : logLevel = @"Info   "; break;
        case DDLogFlagDebug    : logLevel = @"Debug  "; break;
        default                : logLevel = @"Verbose"; break;
    }
    NSString *dateString = logMessage->_timestamp == nil ? @"" : [_dateFormatter stringFromDate:logMessage->_timestamp];
    return [NSString stringWithFormat:@"%@ @%@ |%@| %@", dateString, logMessage->_queueLabel, logLevel, logMessage->_message];
}

@end
