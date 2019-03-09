//
//  S1Parser.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@class S1Topic;

NS_ASSUME_NONNULL_BEGIN

@interface S1Parser : NSObject

+ (NSArray<S1Topic *> *)topicsFromPersonalInfoHTMLData:(NSData *)rawData;

+ (S1Topic *_Nullable)extractTopicInfoFromLink:(NSString *)URLString;

@end

NS_ASSUME_NONNULL_END
