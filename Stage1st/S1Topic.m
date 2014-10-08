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
    return [NSString stringWithFormat:@"[Topic] ID:%@, Page & Position:%@ %@", self.topicID, self.lastViewedPage, self.lastViewedPosition];
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

#pragma mark - Update

- (void)updateWithTopic:(S1Topic *)topic {
    if (topic.formhash != nil) {
        self.formhash = topic.formhash;
    }
    if (topic.title != nil) {
        self.title = topic.title;
    }
    if (topic.replyCount != nil) {
        self.replyCount = topic.replyCount;
    }
    if (topic.formhash != nil) {
        self.formhash = topic.formhash;
    }
    if (topic.totalPageCount != nil) {
        self.totalPageCount = topic.totalPageCount;
    }
}
@end
