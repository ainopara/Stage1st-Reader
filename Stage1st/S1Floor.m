//
//  S1Floor.m
//  Stage1st
//
//  Created by Zheng Li on 3/14/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1Floor.h"

static NSString *const k_floorID = @"floorID";
static NSString *const k_indexMark  = @"indexMark";
static NSString *const k_author = @"author";
static NSString *const k_authorID  = @"authorID";
static NSString *const k_postTime = @"postTime";
static NSString *const k_content = @"content";
static NSString *const k_poll = @"poll";
static NSString *const k_message = @"message";
static NSString *const k_imageAttachmentList = @"imageAttachmentList";
static NSString *const k_firstQuoteReplyFloorID = @"firstQuoteReplyFloorID";

@implementation S1Floor

#pragma mark - Coding

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super init])) {
        _floorID = [aDecoder decodeObjectForKey:k_floorID];
        _indexMark = [aDecoder decodeObjectForKey:k_indexMark];
        _author = [aDecoder decodeObjectForKey:k_author];
        _authorID = [aDecoder decodeObjectForKey:k_authorID];
        _postTime = [aDecoder decodeObjectForKey:k_postTime];
        _content = [aDecoder decodeObjectForKey:k_content];
        _poll = [aDecoder decodeObjectForKey:k_poll];
        _message = [aDecoder decodeObjectForKey:k_message];
        _imageAttachmentList = [aDecoder decodeObjectForKey:k_imageAttachmentList];
        _firstQuoteReplyFloorID = [aDecoder decodeObjectForKey:k_firstQuoteReplyFloorID];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_floorID forKey:k_floorID];
    [aCoder encodeObject:_indexMark forKey:k_indexMark];
    [aCoder encodeObject:_author forKey:k_author];
    [aCoder encodeObject:_authorID forKey:k_authorID];
    [aCoder encodeObject:_postTime forKey:k_postTime];
    [aCoder encodeObject:_content forKey:k_content];
    [aCoder encodeObject:_poll forKey:k_poll];
    [aCoder encodeObject:_message forKey:k_message];
    [aCoder encodeObject:_imageAttachmentList forKey:k_imageAttachmentList];
    [aCoder encodeObject:_firstQuoteReplyFloorID forKey:k_firstQuoteReplyFloorID];
}

@end
