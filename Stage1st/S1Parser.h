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
+ (NSMutableArray *)topicsFromAPI:(NSDictionary *)responseDict;
+ (NSArray *)contentsFromHTMLData:(NSData *)rawData;
+ (NSArray *)contentsFromAPI:(NSDictionary *)responseDict;

+ (NSArray *)topicsFromSearchResultHTMLData:(NSData *)rawData;

+ (NSString *)generateContentPage:(NSArray *)floorList withTopic:(S1Topic *)topic;

+ (NSString *)formhashFromPage:(NSString *)HTMLString;
+ (NSUInteger)totalPagesFromThreadString:(NSString *)HTMLString;
+ (NSUInteger)replyCountFromThreadString:(NSString *)HTMLString;

+ (NSMutableDictionary *)replyFloorInfoFromResponseString:(NSString *)ResponseString;

+ (NSString *)loginUserName:(NSString *)HTMLString;

+ (NSNumber *)extractTopicIDFromLink:(NSString *)URLString;
+ (NSString *)topicTitleFromPage:(NSData *)rawData;
+ (NSString *)messageFromPage:(NSData *)rawData;

+ (S1Topic *)topicInfoFromThreadPage:(NSData *)rawData  andPage:(NSNumber *)page;
+ (S1Topic *)topicInfoFromAPI:(NSDictionary *)responseDict;
@end
