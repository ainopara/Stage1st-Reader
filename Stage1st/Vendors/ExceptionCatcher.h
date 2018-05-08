//
//  ExceptionCatcher.h
//  Stage1st
//
//  Created by Zheng Li on 2018/5/8.
//  Copyright © 2018 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ExceptionCatcher : NSObject

+ (BOOL)catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error;

@end
