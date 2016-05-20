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

@class S1Floor;

NS_ASSUME_NONNULL_BEGIN

@interface S1Topic : MyDatabaseObject<NSCoding>
// Basic
@property (nonatomic, copy) NSNumber *topicID;
// To show in topic list
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSNumber *replyCount;
@property (nonatomic, copy, nullable) NSNumber *lastReplyCount;
@property (nonatomic, copy, nullable) NSNumber *favorite;
@property (nonatomic, copy, nullable) NSDate *favoriteDate;
@property (nonatomic, copy, nullable) NSDate *lastViewedDate;
@property (nonatomic, copy, nullable) NSNumber *lastViewedPosition;

// To generate content page & Search post owner
@property (nonatomic, copy, nullable) NSNumber *authorUserID;
@property (nonatomic, copy, nullable) NSString *authorUserName;

// Used to update page count in content view
@property (nonatomic, copy, nullable) NSNumber *totalPageCount;
// Not Used
@property (nonatomic, copy, nullable) NSNumber *fID;

// For Reply
@property (nonatomic, copy, nullable) NSString *formhash;

// For Tracing
@property (nonatomic, copy, nullable) NSNumber *lastViewedPage;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, S1Floor *> *floors; // indexMark : floor

@property (nonatomic, copy, nullable) NSString *message;

// Model Version
@property (nonatomic, copy, nullable) NSNumber *modelVersion;

- (instancetype)initWithTopicID:(NSNumber *)topicID;
- (instancetype)initWithRecord:(CKRecord *)record;

// Update
- (void)addDataFromTracedTopic:(S1Topic *)topic;
- (void)updateFromTopic:(S1Topic *)topic;
- (void)absorbTopic:(S1Topic *)topic;

@end

NS_ASSUME_NONNULL_END
