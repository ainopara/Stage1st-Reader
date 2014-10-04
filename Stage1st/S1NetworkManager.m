//
//  S1NetworkManager.m
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1NetworkManager.h"
#import "S1HTTPClient.h"

@interface S1NetworkManager ()

@property (strong, nonatomic) S1HTTPClient *client;

@end

@implementation S1NetworkManager

- (instancetype)init {
    self = [super init];
    self.client = [S1HTTPClient sharedClient];
    return self;
}

- (void)requestTopicListForKey:(NSString *)keyID
                      withPage:(NSUInteger)page
                       success:(void (^)(NSURLSessionDataTask *, id))success
                       failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *url = @"forum.php";
    if (page == 1) {
        NSDictionary *params = @{@"mod": @"forumdisplay", @"mobile": @"no", @"fid": keyID};
        [self.client GET:url parameters:params success:success failure:failure];
    } else {
        NSDictionary *params = @{@"mod": @"forumdisplay", @"mobile": @"no", @"fid": keyID, @"page": [NSNumber numberWithUnsignedInteger:page]};
        [self.client GET:url parameters:params success:success failure:failure];
    }
}

-(void) cancelRequest
{
    [[self.client session] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        // NSLog(@"%lu,%lu,%lu",(unsigned long)dataTasks.count, (unsigned long)uploadTasks.count, (unsigned long)downloadTasks.count);
        for (NSURLSessionDataTask* task in downloadTasks) {
            [task cancel];
        }
        for (NSURLSessionDataTask* task in dataTasks) {
            [task cancel];
        }
    }];
}

@end
