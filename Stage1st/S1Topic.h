//
//  S1Topic.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S1Topic : NSObject <NSCoding>
//Basic
@property (nonatomic, copy) NSNumber *topicID;
//To show in topic list
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSNumber *replyCount;
@property (nonatomic, copy) NSNumber *lastReplyCount;
@property (nonatomic, copy) NSNumber *favorite;
@property (nonatomic, copy) NSDate *lastViewedDate;
@property (nonatomic, copy) NSNumber *lastViewedPosition;
@property (nonatomic, copy) NSString *highlight;
//To generate content page
@property (nonatomic, copy) NSNumber *authorUserID;

//For Search
@property (nonatomic, copy) NSNumber *fID;
@property (nonatomic, copy) NSString *authorUserName;
//Used to update page count in content view
@property (nonatomic, copy) NSNumber *totalPageCount;
//Not Used
@property (nonatomic, copy) NSNumber *visitCount;
//For Reply
@property (nonatomic, copy) NSString *formhash;

//For Tracing
@property (nonatomic, copy) NSNumber *lastViewedPage;
@property (nonatomic, copy) NSMutableDictionary *floors;

@property (nonatomic, copy) NSString *message;

- (void)addDataFromTracedTopic:(S1Topic *)topic;
@end