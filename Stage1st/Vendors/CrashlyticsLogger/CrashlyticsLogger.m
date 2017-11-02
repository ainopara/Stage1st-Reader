//
//  CrashliyticsLogger.m
//  Stage1st
//
//  Created by Zheng Li on 3/6/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

#import "CrashlyticsLogger.h"
#import <Crashlytics/Crashlytics.h>

NS_ASSUME_NONNULL_BEGIN

@implementation CrashlyticsLogger

- (void)logMessage:(DDLogMessage *)logMessage
{
    NSString *logMsg = logMessage->_message;

    if (_logFormatter) {
        logMsg = [_logFormatter formatLogMessage:logMessage];
    }

    if (logMsg) {
        CLSLog(@"%@", logMsg);
    }
}


+ (CrashlyticsLogger *)sharedInstance
{
    static dispatch_once_t pred = 0;
    static CrashlyticsLogger *_sharedInstance = nil;

    dispatch_once(&pred, ^{
        _sharedInstance = [[self alloc] init];
    });

    return _sharedInstance;
}

- (NSString *)loggerName
{
    return @"com.ainopara.crashlyticsLogger";
}

@end

NS_ASSUME_NONNULL_END
