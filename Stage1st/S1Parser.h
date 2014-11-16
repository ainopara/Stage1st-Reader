//
//  S1Parser.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
@class S1Topic;

@interface S1Parser : NSObject

+ (NSArray *)topicsFromHTMLData:(NSData *)rawData withContext:(NSDictionary *)context;
+ (NSArray *)contentsFromHTMLData:(NSData *)rawData;
+ (NSArray *)contentsFromAPI:(NSDictionary *)responseDict;
+ (NSString *)generateContentPage:(NSArray *)floorList withTopic:(S1Topic *)topic;

+ (NSString *)formhashFromThreadString:(NSString *)HTMLString;
+ (NSUInteger)totalPagesFromThreadString:(NSString *)HTMLString;
+ (NSUInteger)replyCountFromThreadString:(NSString *)HTMLString;

+ (NSMutableDictionary *)replyFloorInfoFromResponseString:(NSString *)ResponseString;

+ (NSString *)loginUserName:(NSString *)HTMLString;

@end
