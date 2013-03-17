//
//  S1Topic.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Topic.h"

@implementation S1Topic


- (NSString *)description
{
    return [NSString stringWithFormat:@"[Topic] ID:%@, TimeStamp:%@", self.topicID, self.lastViewedDate];
}


#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.fID forKey:@"FID"];
    [encoder encodeObject:self.topicID forKey:@"TopicID"];
    [encoder encodeObject:self.title forKey:@"Title"];
    [encoder encodeObject:self.replyCount forKey:@"ReplyCount"];
    [encoder encodeObject:self.lastViewedPage forKey:@"LastViewedPage"];
    [encoder encodeObject:self.lastViewedDate forKey:@"LastViewedDate"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super init]) {
        self.fID = [decoder decodeObjectForKey:@"FID"];
        self.topicID = [decoder decodeObjectForKey:@"TopicID"];
        self.title = [decoder decodeObjectForKey:@"Title"];
        self.replyCount = [decoder decodeObjectForKey:@"ReplyCount"];
        self.lastViewedPage = [decoder decodeObjectForKey:@"LastViewedPage"];
        self.lastViewedDate = [decoder decodeObjectForKey:@"LastViewedDate"];
    }
    return self;
}

@end
