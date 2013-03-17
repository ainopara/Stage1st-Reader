//
//  S1Topic.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S1Topic : NSObject <NSCoding>

@property (nonatomic, copy) NSString *fID;
@property (nonatomic, copy) NSString *topicID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *replyCount;

//For Tracing
@property (nonatomic, copy) NSString *lastViewedPage;
@property (nonatomic, copy) NSDate *lastViewedDate;

@end
