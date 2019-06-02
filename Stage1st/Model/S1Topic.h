//
//  S1Topic.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>
#import "MyDatabaseObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface S1Topic : MyDatabaseObject<NSCoding>
// Basic
@property (nonatomic, copy, readonly) NSNumber *topicID; // traced

@property (nonatomic, copy, nullable) NSString *title; // traced
@property (nonatomic, copy, nullable) NSNumber *replyCount; // traced
@property (nonatomic, copy, nullable) NSNumber *authorUserID; // traced

@property (nonatomic, copy, nullable) NSNumber *favorite; // traced
@property (nonatomic, copy, nullable) NSDate *favoriteDate; // traced

@property (nonatomic, copy, nullable) NSDate *lastViewedDate; // traced
@property (nonatomic, copy, nullable) NSNumber *lastViewedPage; // traced
@property (nonatomic, copy, nullable) NSNumber *lastViewedPosition; // traced

@property (nonatomic, copy, nullable) NSNumber *fID; // traced

@property (nonatomic, copy, nullable) NSNumber *modelVersion; // traced

@property (nonatomic, copy, nullable) NSNumber *lastReplyCount;
@property (nonatomic, strong, nullable) NSDate *lastReplyDate;
@property (nonatomic, copy, nullable) NSString *authorUserName;
@property (nonatomic, copy, nullable) NSString *formhash;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSString *locateFloorIDTag;

- (instancetype)initWithTopicID:(NSNumber *)topicID;
- (instancetype)initWithRecord:(CKRecord *)record;

// Used to resolve merge conflict
- (void)absorbTopic:(S1Topic *)topic;

@end

NS_ASSUME_NONNULL_END
