//
//  S1Topic.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Topic.h"

/**
 * Keys for encoding / decoding (to avoid typos)
 **/
static NSString *const k_version = @"version";
static NSString *const k_topicID = @"topicID";
static NSString *const k_title  = @"title";
static NSString *const k_replyCount = @"replyCount";
static NSString *const k_fID  = @"fID";
static NSString *const k_authorID  = @"authorID";
static NSString *const k_lastViewedDate = @"lastViewedDate";
static NSString *const k_lastViewedPage = @"lastViewedPage";
static NSString *const k_lastViewedPosition = @"lastViewedPosition";
static NSString *const k_favorite = @"favorite";
static NSString *const k_favoriteDate = @"favoriteDate";

@implementation S1Topic

- (instancetype)initWithTopicID:(NSNumber *)topicID {
    self = [super init];
    if (self != nil) {
        if (topicID == nil) {
            return nil;
        }
        _topicID = topicID;
        _favorite = @(NO);
        _modelVersion = @1;
    }
    return self;
}

- (instancetype)initWithRecord:(CKRecord *)record {
    if (![record.recordType isEqualToString:@"topic"])
    {
        NSAssert(NO, @"Attempting to create topic from non-topic record"); // For debug builds
        return nil;                                                      // For release builds
    }
    
    if ((self = [super init]))
    {
        _topicID = @([record.recordID.recordName integerValue]);
        
        NSSet *cloudKeys = self.allCloudProperties;
        for (NSString *cloudKey in cloudKeys)
        {
            if (![cloudKey isEqualToString:k_topicID])
            {
                [self setLocalValueFromCloudValue:[record objectForKey:cloudKey] forCloudKey:cloudKey];
            }
        }
        if (_favorite == nil) {
            _favorite = @(NO);
        }
        _modelVersion = @1;
    }
    return self;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super init])) {
        _topicID = [aDecoder decodeObjectForKey:k_topicID];
        _title = [aDecoder decodeObjectForKey:k_title];
        _fID = [aDecoder decodeObjectForKey:k_fID];
        _authorUserID = [aDecoder decodeObjectForKey:k_authorID];
        _replyCount = [aDecoder decodeObjectForKey:k_replyCount];
        _lastViewedDate = [aDecoder decodeObjectForKey:k_lastViewedDate];
        _lastViewedPage = [aDecoder decodeObjectForKey:k_lastViewedPage];
        _lastViewedPosition = [aDecoder decodeObjectForKey:k_lastViewedPosition];
        _favorite = [aDecoder decodeObjectForKey:k_favorite];
        _favoriteDate = [aDecoder decodeObjectForKey:k_favoriteDate];
        _modelVersion = [aDecoder decodeObjectForKey:k_version];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_topicID forKey:k_topicID];
    [aCoder encodeObject:_title forKey:k_title];
    [aCoder encodeObject:_fID forKey:k_fID];
    [aCoder encodeObject:_authorUserID forKey:k_authorID];
    [aCoder encodeObject:_replyCount forKey:k_replyCount];
    [aCoder encodeObject:_lastViewedDate forKey:k_lastViewedDate];
    [aCoder encodeObject:_lastViewedPage forKey:k_lastViewedPage];
    [aCoder encodeObject:_lastViewedPosition forKey:k_lastViewedPosition];
    [aCoder encodeObject:_favorite forKey:k_favorite];
    [aCoder encodeObject:_favoriteDate forKey:k_favoriteDate];
    [aCoder encodeObject:_modelVersion forKey:k_version];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    S1Topic *copy = [super copyWithZone:zone]; // Be sure to invoke [MyDatabaseObject copyWithZone:] !
    copy->_topicID = _topicID;
    copy->_title = _title;
    copy->_replyCount = _replyCount;
    copy->_lastReplyCount = _lastReplyCount;
    copy->_favorite = _favorite;
    copy->_favoriteDate = _favoriteDate;
    copy->_lastViewedDate = _lastViewedDate;
    copy->_lastViewedPosition = _lastViewedPosition;
    copy->_authorUserID = _authorUserID;
    copy->_authorUserName = _authorUserName;
    copy->_fID = _fID;
    copy->_formhash = _formhash;
    copy->_lastViewedPage = _lastViewedPage;
    copy->_lastReplyDate = _lastReplyDate;
    copy->_message = _message;
    copy->_modelVersion = _modelVersion;
    copy->_locateFloorIDTag = _locateFloorIDTag;
    return copy;
}

#pragma mark - Description

- (NSString *)description {
    NSMutableString *despString = [NSMutableString stringWithFormat:@"Topic(Version: %@) ID: %@:", self.modelVersion, self.topicID];
    [despString appendString:@"\n[Basic Information]"];
    [despString appendFormat:@"\nTitle: %@", self.title];
    [despString appendFormat:@"\nFromhash: %@", self.formhash];
    [despString appendFormat:@"\nJumpToFloor: %@", self.locateFloorIDTag];
    
    [despString appendFormat:@"\n[Changed CloudKit Property] Count: %lu", (unsigned long)[self.changedCloudProperties count]];
    for (NSString *property in self.changedCloudProperties) {
        [despString appendFormat:@"\n%@: %@ -> %@", property, [self.originalCloudValues valueForKey:property], [self valueForKey:property]];
    }

    return despString;
}

#pragma mark - Update

// To resolve merge conflict
- (void)absorbTopic:(S1Topic *)topic {
    NSAssert(!self.isImmutable, @"should be mutable to call this method");
    if ([topic.topicID isEqualToNumber:self.topicID]) {
        if ([topic.lastViewedDate timeIntervalSince1970] > [self.lastViewedDate timeIntervalSince1970]) {
            if (topic.title != nil && (![self.title isEqualToString:topic.title])) {
                self.title = topic.title;
            }
            if (topic.replyCount != nil && (![self.replyCount isEqualToNumber:topic.replyCount])) {
                self.replyCount = topic.replyCount;
            }
            if (topic.fID != nil && (![self.fID isEqualToNumber:topic.fID])) {
                self.fID = topic.fID;
            }
            if (topic.lastViewedDate != nil && (![self.lastViewedDate isEqualToDate:topic.lastViewedDate])) {
                self.lastViewedDate = topic.lastViewedDate;
            }
            if (topic.lastViewedPage != nil && (![self.lastViewedPage isEqualToNumber:topic.lastViewedPage])) {
                self.lastViewedPage = topic.lastViewedPage;
            }
            if (topic.lastViewedPosition != nil && (![self.lastViewedPosition isEqualToNumber:topic.lastViewedPosition])) {
                self.lastViewedPosition = topic.lastViewedPosition;
            }
        }
        if ([topic.favorite boolValue] == YES && ![self.favorite boolValue]) {
            self.favorite = [NSNumber numberWithBool:YES];
            self.favoriteDate = topic.favoriteDate;
        }
        if (self.title == nil) {
            self.title = @"";
        }
    }
}

#pragma mark - MyDatabaseObject overrides

+ (BOOL)storesOriginalCloudValues {
    return YES;
}

+ (NSMutableDictionary *)mappings_localKeyToCloudKey {
    NSMutableDictionary *mappings_localKeyToCloudKey = [super mappings_localKeyToCloudKey];
    [mappings_localKeyToCloudKey removeObjectForKey:@"formhash"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"floors"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"message"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"lastReplyCount"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"authorUserName"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"lastReplyDate"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"locateFloorIDTag"];
    return mappings_localKeyToCloudKey;
    
}

- (id)cloudValueForCloudKey:(NSString *)cloudKey {
    // Override me if needed.
    // For example:
    //
    // - (id)cloudValueForCloudKey:(NSString *)cloudKey
    // {
    //     if ([cloudKey isEqualToString:@"color"])
    //     {
    //         // We store UIColor in the cloud as a string (r,g,b,a)
    //         return ConvertUIColorToNSString(self.color);
    //     }
    //     else
    //     {
    //         return [super cloudValueForCloudKey:cloudKey];
    //     }
    // }
    if ([cloudKey isEqualToString:@"title"] && self.title == nil) {
        return @"";
    }
    return [super cloudValueForCloudKey:cloudKey];
}

- (void)setLocalValueFromCloudValue:(id)cloudValue forCloudKey:(NSString *)cloudKey {
    // Override me if needed.
    // For example:
    //
    // - (void)setLocalValueFromCloudValue:(id)cloudValue forCloudKey:(NSString *)cloudKey
    // {
    //     if ([cloudKey isEqualToString:@"color"])
    //     {
    //         // We store UIColor in the cloud as a string (r,g,b,a)
    //         self.color = ConvertNSStringToUIColor(cloudValue);
    //     }
    //     else
    //     {
    //         return [super setLocalValueForCloudValue:cloudValue cloudKey:cloudKey];
    //     }
    // }
    if ([cloudKey isEqualToString:@"title"] && cloudValue == nil) {
        self.title = @"";
    } else {
        return [super setLocalValueFromCloudValue:cloudValue forCloudKey:cloudKey];
    }
}

#pragma mark KVO overrides

- (void)setNilValueForKey:(NSString *)key {
    [super setNilValueForKey:key];
}

@end
