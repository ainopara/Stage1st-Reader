//
//  CrashlyticsLogger.h
//  Stage1st
//
//  Created by Zheng Li on 3/6/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

@class DDAbstractLogger;

@interface CrashlyticsLogger : DDAbstractLogger

+ (CrashlyticsLogger*)sharedInstance;

@end
