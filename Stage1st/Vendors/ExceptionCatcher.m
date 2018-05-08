//
//  ExceptionCatcher.m
//  Stage1st
//
//  Created by Zheng Li on 2018/5/8.
//  Copyright © 2018 Renaissance. All rights reserved.
//

#import "ExceptionCatcher.h"

@implementation ExceptionCatcher

+ (BOOL)catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        *error = [[NSError alloc] initWithDomain:exception.name code:0 userInfo:exception.userInfo];
        return NO;
    }
}

@end
