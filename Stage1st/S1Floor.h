//
//  S1Floor.h
//  Stage1st
//
//  Created by Zheng Li on 3/14/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

@interface S1Floor : MTLModel

@property (nonatomic, copy) NSNumber *floorID;
@property (nonatomic, copy) NSString *indexMark;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSNumber *authorID;
@property (nonatomic, copy) NSDate *postTime;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, copy) NSString *poll;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSArray *imageAttachmentList;

@property (nonatomic, copy) NSNumber *firstQuoteReplyFloorID;

@end
