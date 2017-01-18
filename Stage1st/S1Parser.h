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

+ (NSMutableArray *)topicsFromAPI:(NSDictionary *)responseDict;
+ (NSArray *)contentsFromAPI:(NSDictionary *)responseDict;

+ (NSArray *)topicsFromSearchResultHTMLData:(NSData *)rawData;

+ (NSMutableDictionary *)replyFloorInfoFromResponseString:(NSString *)ResponseString;

+ (NSString *)loginUserName:(NSString *)HTMLString;

+ (S1Topic *)extractTopicInfoFromLink:(NSString *)URLString;
+ (NSString *)topicTitleFromPage:(NSData *)rawData;
+ (NSString *)messageFromPage:(NSData *)rawData;

+ (S1Topic *)topicInfoFromThreadPage:(NSData *)rawData  page:(NSNumber *)page withTopicID:(NSNumber *)topicID;
+ (S1Topic *)topicInfoFromAPI:(NSDictionary *)responseDict;

+ (NSArray *)topicsFromPersonalInfoHTMLData:(NSData *)rawData;
+ (NSDictionary<NSString *, NSString *> *)extractQuerysFromURLString:(NSString *)URLString;

@end
