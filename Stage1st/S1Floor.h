//
//  S1Floor.h
//  Stage1st
//
//  Created by Zheng Li on 3/14/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface S1Floor : NSObject

@property (nonatomic, copy) NSNumber *floorID;
@property (nonatomic, copy, nullable) NSString *indexMark;
@property (nonatomic, copy, nullable) NSString *author;
@property (nonatomic, copy, nullable) NSNumber *authorID;
@property (nonatomic, copy, nullable) NSDate *postTime;
@property (nonatomic, copy, nullable) NSString *content;
@property (nonatomic, copy, nullable) NSString *poll;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSArray *imageAttachmentList;

@property (nonatomic, copy, nullable) NSNumber *firstQuoteReplyFloorID;

@end

NS_ASSUME_NONNULL_END
