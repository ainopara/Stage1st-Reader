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

@interface S1Topic : MyDatabaseObject<NSCoding, NSCopying>
// Basic
@property (nonatomic, copy) NSNumber *topicID;
// To show in topic list
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSNumber *replyCount;
@property (nonatomic, copy) NSNumber *lastReplyCount;
@property (nonatomic, copy) NSNumber *favorite;
@property (nonatomic, copy) NSDate *favoriteDate;
@property (nonatomic, copy) NSDate *lastViewedDate;
@property (nonatomic, copy) NSNumber *lastViewedPosition;

// To generate content page & Search post owner
@property (nonatomic, copy) NSNumber *authorUserID;
@property (nonatomic, copy) NSString *authorUserName;

// Used to update page count in content view
@property (nonatomic, copy) NSNumber *totalPageCount;
// Not Used
@property (nonatomic, copy) NSNumber *fID;

// For Reply
@property (nonatomic, copy) NSString *formhash;

// For Tracing
@property (nonatomic, copy) NSNumber *lastViewedPage;
@property (nonatomic, copy) NSDictionary *floors;

@property (nonatomic, copy) NSString *message;


- (instancetype)initWithRecord:(CKRecord *)record;
// Update
- (void)addDataFromTracedTopic:(S1Topic *)topic;
- (void)updateFromTopic:(S1Topic *)topic;
- (void)absorbTopic:(S1Topic *)topic;
@end