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
#import "S1Floor.h"
#import "S1Parser.h"

@interface S1ContentViewModel ()

@property (nonatomic, strong) S1DataCenter *dataCenter;

@end


@implementation S1ContentViewModel

- (id)initWithDataCenter:(S1DataCenter *)dataCenter {
    self = [super init];
    if (self) {
        // Initialization code
        self.dataCenter = dataCenter;
    }
    return self;
}

- (void)contentPageForTopic:(S1Topic *)topic withPage:(NSUInteger)page success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure {
    [self.dataCenter floorsForTopic:topic withPage:[NSNumber numberWithUnsignedInteger:page] success:^(NSArray *floorList) {
        //Set Floors
        NSMutableDictionary *floors;
        if(topic.floors != nil) {
            floors = [[NSMutableDictionary alloc] initWithDictionary:topic.floors];
        } else {
            floors = [[NSMutableDictionary alloc] init];
        }
        for (S1Floor *floor in floorList) {
            [floors setValue:floor forKey:floor.indexMark];
        }
        topic.floors = floors;
        
        NSString *string = [S1Parser generateContentPage:floorList withTopic:topic];
        success(string);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

@end
