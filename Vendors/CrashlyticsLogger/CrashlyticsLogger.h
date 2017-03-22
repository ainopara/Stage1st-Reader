//
//  CrashlyticsLogger.h
//  Stage1st
//
//  Created by Zheng Li on 3/6/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

@class DDAbstractLogger;

NS_ASSUME_NONNULL_BEGIN

@interface CrashlyticsLogger : DDAbstractLogger

+ (CrashlyticsLogger *)sharedInstance;

@end

NS_ASSUME_NONNULL_END
