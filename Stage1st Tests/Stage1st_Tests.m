//
//  Stage1st_Tests.m
//  Stage1st Tests
//
//  Created by Zheng Li on 10/31/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
//#import "S1DataCenter.h"
//#import "S1ContentViewModel.h"
#import "S1Parser.h"
#import "S1Topic.h"

@interface Stage1st_Tests : XCTestCase
//@property (nonatomic,strong) S1ContentViewModel *contentViewModel;
//@property (nonatomic,strong) S1DataCenter *dataCenter;
@property (nonatomic,strong) NSData *data;
@property (nonatomic,strong) S1Topic *topic;
@end

@implementation Stage1st_Tests

- (void)setUp {
    [super setUp];
    self.data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://bbs.saraba1st.com/2b/thread-1069549-1-1.html"]];
    self.topic = [[S1Topic alloc] init];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testPerformanceContentParse {
    // This is an example of a performance test case.
    NSNumber *page = @1;
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        [S1Parser contentsFromHTMLData:self.data];
        
        // get formhash
        NSString* HTMLString = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
        [self.topic setFormhash:[S1Parser formhashFromThreadString:HTMLString]];
        
        //set reply count
        if ([page isEqualToNumber:@1]) {
            NSInteger parsedReplyCount = [S1Parser replyCountFromThreadString:HTMLString];
            if (parsedReplyCount != 0) {
                [self.topic setReplyCount:[NSNumber numberWithInteger:parsedReplyCount]];
            }
        }
        // update total page
        NSInteger parsedTotalPages = [S1Parser totalPagesFromThreadString:HTMLString];
        if (parsedTotalPages != 0) {
            [self.topic setTotalPageCount:[NSNumber numberWithInteger:parsedTotalPages]];
        }
    }];
}

- (void)testPerformanceContentGenerate {
    NSArray *floorList = [S1Parser contentsFromHTMLData:self.data];
    
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        [S1Parser generateContentPage:floorList withTopic:self.topic];
    }];
}

@end
