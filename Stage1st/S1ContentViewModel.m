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

//@implementation S1ContentViewModel
//
//- (instancetype)initWithTopic:(S1Topic *)topic dataCenter:(S1DataCenter *)dataCenter {
//    self = [super init];
//    if (self != nil) {
//        __weak __typeof__(self) weakSelf = self;
//        [RACObserve(self.topic, replyCount) subscribeNext:^(id x) {
//            __strong __typeof__(self) strongSelf = weakSelf;
//            if (strongSelf == nil) {
//                return;
//            }
//
//            DDLogInfo(@"[ContentVM] reply count changed: %@", x);
//            strongSelf.totalPages = ([x unsignedIntegerValue] / 30) + 1;
//        }];
//    }
//
//    return self;
//}
//
//- (void)setCurrentPage:(NSUInteger)currentPage {
//    _previousPage = _currentPage;
//    _currentPage = currentPage;
//}
//
//@end
