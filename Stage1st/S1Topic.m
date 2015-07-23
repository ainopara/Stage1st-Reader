//
//  S1Topic.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Topic.h"

@implementation S1Topic

#pragma mark - Core Data Serializing

+ (NSString *)managedObjectEntityName {
    return @"Topic";
}

+ (NSDictionary *)managedObjectKeysByPropertyKey {
    return @{@"topicID" : @"topicID",
             @"title" : @"title",
             @"replyCount" : @"replyCount",
             @"fID" : @"fID",
             @"favorite" : @"favorite",
             @"lastViewedDate" : @"lastViewedDate",
             @"lastViewedPage" : @"lastViewedPage",
             @"lastViewedPosition" : @"lastViewedPosition"};
}
+ (NSSet *)propertyKeysForManagedObjectUniquing {
    return [[NSSet alloc] initWithArray:@[@"topicID"]];
}
#pragma mark - Coding
+ (NSDictionary *)encodingBehaviorsByPropertyKey {
    NSDictionary *excludeProperties = @{
                                        NSStringFromSelector(@selector(floors)): @(MTLModelEncodingBehaviorExcluded)
                                        };
    NSDictionary *encodingBehaviors = [[super encodingBehaviorsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:excludeProperties];
    return encodingBehaviors;
}

#pragma mark - Update

- (void)addDataFromTracedTopic:(S1Topic *)topic {
    if (self.topicID == nil && topic.topicID != nil) {
        self.topicID = topic.topicID;
    }
    if (self.title == nil && topic.title != nil) {
        self.title = topic.title;
    }
    if (self.replyCount == nil && topic.replyCount != nil) {
        self.replyCount = topic.replyCount;
    }
    if (self.fID == nil && topic.fID != nil) {
        self.fID = topic.fID;
    }
    self.lastReplyCount = topic.replyCount;
    self.lastViewedPage = topic.lastViewedPage;
    self.lastViewedPosition = topic.lastViewedPosition;
    self.visitCount = topic.visitCount;
    self.favorite = topic.favorite;
}

- (void)updateFromTopic:(S1Topic *)topic {
    if (topic.title != nil) {
        self.title = topic.title;
    }
    if (topic.replyCount != nil) {
        self.replyCount = topic.replyCount;
    }
    if (topic.totalPageCount != nil) {
        self.totalPageCount = topic.totalPageCount;
    }
    if (topic.authorUserID != nil) {
        self.authorUserID = topic.authorUserID;
    }
    if (topic.authorUserName != nil) {
        self.authorUserName = topic.authorUserName;
    }
    if (topic.formhash != nil) {
        self.formhash = topic.formhash;
    }
    if (topic.message != nil) {
        self.message = topic.message;
    }
}

- (BOOL)absorbTopic:(S1Topic *)topic {
    if ([topic.topicID isEqualToNumber:self.topicID]) {
        if ([topic.lastViewedDate timeIntervalSince1970] > [self.lastViewedDate timeIntervalSince1970]) {
            self.title = topic.title;
            self.replyCount = topic.replyCount;
            self.fID = topic.fID;
            self.lastViewedDate = topic.lastViewedDate;
            self.lastViewedPage = topic.lastViewedPage;
            self.lastViewedPosition = topic.lastViewedPosition;
            self.visitCount = [self.visitCount integerValue] > [topic.visitCount integerValue] ? self.visitCount : topic.visitCount;
            return YES;
        }
    }
    return NO;
    
}
/*
+ (NSValueTransformer *)lastViewedDateEntityAttributeTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSNumber *seconds) {
        return [[NSDate alloc] initWithTimeIntervalSince1970: [seconds doubleValue]];
    } reverseBlock:^(NSDate *date) {
        return [NSNumber numberWithDouble:[date timeIntervalSince1970]];
    }];
}*/
- (BOOL)shouldOverwriteManagedObject:(NSManagedObject *)managedObject {
    NSDate *persistedDate = [managedObject valueForKey:@"lastViewedDate"];
    if (persistedDate) {
        return [self.lastViewedDate compare:persistedDate] == NSOrderedDescending;
    }
    return YES;
}

@end
