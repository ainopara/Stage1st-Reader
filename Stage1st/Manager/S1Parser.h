//
//  S1Parser.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@class S1Topic;
@class Floor;

NS_ASSUME_NONNULL_BEGIN

@interface S1Parser : NSObject

+ (NSMutableArray<S1Topic *> *)topicsFromAPI:(NSDictionary *)responseDict;
+ (NSArray<Floor *> *)contentsFromAPI:(NSDictionary *)responseDict;

+ (NSArray *)topicsFromSearchResultHTMLData:(NSData *)rawData;

+ (NSMutableDictionary *_Nullable)replyFloorInfoFromResponseString:(NSString *)ResponseString;

+ (NSString *_Nullable)loginUserName:(NSString *)HTMLString;

+ (S1Topic *_Nullable)extractTopicInfoFromLink:(NSString *)URLString;
+ (NSString *_Nullable)topicTitleFromPage:(NSData *)rawData;
+ (NSString *_Nullable)messageFromPage:(NSData *)rawData;

+ (S1Topic *)topicInfoFromThreadPage:(NSData *)rawData page:(NSNumber *)page withTopicID:(NSNumber *)topicID;
+ (S1Topic *_Nullable)topicInfoFromAPI:(NSDictionary *)responseDict;

+ (NSArray *)topicsFromPersonalInfoHTMLData:(NSData *)rawData;
+ (NSDictionary<NSString *, NSString *> *_Nullable)extractQuerysFromURLString:(NSString *)URLString;

@end

NS_ASSUME_NONNULL_END
