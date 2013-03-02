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
    return [NSString stringWithFormat:@"[Topic]ID:%@; Title:%@; Reply:%@", self.topicID, self.title, self.replyCount];
}

@end
