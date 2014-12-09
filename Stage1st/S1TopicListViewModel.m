//
//  S1TopicListViewModel.m
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1TopicListViewModel.h"
#import "S1DataCenter.h"
#import "S1Topic.h"




@interface S1TopicListViewModel ()

@property (nonatomic, strong) S1DataCenter *dataCenter;

@end

@implementation S1TopicListViewModel

- (id)initWithDataCenter:(S1DataCenter *)dataCenter {
    self = [super init];
    if (self) {
        // Initialization code
        self.dataCenter = dataCenter;
    }
    return self;
}

- (void)topicListForKey:(NSString *)key shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    [self.dataCenter topicsForKey:key shouldRefresh:refresh success:^(NSArray *topicList) {
        success(topicList);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (NSDictionary *)internalTopicsInfoFor:(S1InternalTopicListType)type withSearchWord:(NSString *)searchWord andLeftCallback:(void (^)(NSDictionary *))leftTopicsHandler {
    NSArray *topics;
    if (type == S1TopicListHistory) {
        topics = [self.dataCenter historyTopicsWithSearchWord:searchWord andLeftCallback:^(NSArray *fullTopics) {
            leftTopicsHandler([S1TopicListViewModel processTopicHeader:fullTopics withSearchWord:searchWord]);
        }];
    } else if (type == S1TopicListFavorite) {
        topics = [self.dataCenter favoriteTopicsWithSearchWord:searchWord];
    } else {
        return @{@"headers": @[@[]], @"topics":@[@[]]};
    }
    return [S1TopicListViewModel processTopicHeader:topics withSearchWord:searchWord];
    
}

+ (NSDictionary *)processTopicHeader:(NSArray *)topics withSearchWord:(NSString *)searchWord {
    NSMutableArray *processedTopics = [[NSMutableArray alloc] init];
    NSMutableArray *topicHeaderTitles = [[NSMutableArray alloc] init];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:NSLocalizedString(@"TopicListView_ListHeader_Style", @"Header Style")];
    for (S1Topic *topic in topics) {
        topic.highlight = searchWord;
        NSDate *date = topic.lastViewedDate;
        NSString *topicTitle = [formatter stringFromDate:date];
        if ([[formatter stringFromDate:date] isEqualToString:[formatter stringFromDate:[[NSDate alloc] initWithTimeIntervalSinceNow:0]]]) {
            topicTitle = [topicTitle stringByAppendingString:NSLocalizedString(@"TopicListView_ListHeader_Today", @"Today")];
        }
        if ([topicHeaderTitles containsObject:topicTitle]) {
            [[processedTopics objectAtIndex:[topicHeaderTitles indexOfObject:topicTitle]] addObject:topic];
        } else {
            [topicHeaderTitles addObject:topicTitle];
            [processedTopics addObject:[[NSMutableArray alloc] initWithObjects:topic, nil]];
        }
    }
    return @{@"headers":topicHeaderTitles, @"topics":processedTopics};
}
@end
