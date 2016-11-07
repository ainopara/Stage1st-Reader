//
//  S1ContentViewModel.m
//  Stage1st
//
//  Created by Zheng Li on 10/9/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1ContentViewModel.h"
#import "S1DataCenter.h"
#import "S1Topic.h"
#import "S1Parser.h"
#import "DDXML.h"
#import "DDXMLElementAdditions.h"
#import <ReactiveObjc/ReactiveObjC.h>
#import <Reachability/Reachability.h>

@implementation S1ContentViewModel

- (instancetype)initWithTopic:(S1Topic *)topic dataCenter:(S1DataCenter *)dataCenter {
    self = [super init];
    if (self != nil) {
        // Initialization code
        if ([topic isImmutable]) {
            _topic = [topic copy];
        } else {
            _topic = topic;
        }

        if (topic.lastViewedPage != nil) {
            _currentPage = [topic.lastViewedPage unsignedIntegerValue];
        } else {
            _currentPage = 1;
        }
        _previousPage = _currentPage;

        _cachedViewPosition = [[NSMutableDictionary<NSNumber *, NSNumber *> alloc] init];
        if (topic.lastViewedPosition != nil && topic.lastViewedPage != nil) {
            [_cachedViewPosition setObject:topic.lastViewedPosition forKey:topic.lastViewedPage];
        }

        _totalPages = ([topic.replyCount unsignedIntegerValue] / 30) + 1;

        if (_topic.favorite == nil) {
            _topic.favorite = @(NO);
        }

        DDLogInfo(@"[ContentVM] Initialize with TopicID: %@", _topic.topicID);

        _dataCenter = dataCenter;

        __weak __typeof__(self) weakSelf = self;
        [RACObserve(self, currentPage) subscribeNext:^(id x) {
            DDLogDebug(@"[ContentVM] Current page changed to: %@", x);
        }];

        [RACObserve(self.topic, replyCount) subscribeNext:^(id x) {
            __strong __typeof__(self) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }

            DDLogInfo(@"[ContentVM] reply count changed: %@", x);
            strongSelf.totalPages = ([x unsignedIntegerValue] / 30) + 1;
        }];
    }

    return self;
}

- (void)setCurrentPage:(NSUInteger)currentPage {
    _previousPage = _currentPage;
    _currentPage = currentPage;
}

@end
