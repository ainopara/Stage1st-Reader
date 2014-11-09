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
                      withPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *, id))success
                       failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *url = @"forum.php";
    if ([page isEqualToNumber:@1]) {
        NSDictionary *params = @{@"mod": @"forumdisplay",
                                 @"mobile": @"no",
                                 @"fid": keyID};
        [self.client GET:url parameters:params success:success failure:failure];
    } else {
        NSDictionary *params = @{@"mod": @"forumdisplay",
                                 @"mobile": @"no",
                                 @"fid": keyID,
                                 @"page": page};
        [self.client GET:url parameters:params success:success failure:failure];
    }
}

- (void)requestTopicContentForID:(NSNumber *)topicID
                      withPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *, id))success
                       failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *url = @"forum.php";
    if ([page isEqualToNumber: @1]) {
        NSDictionary *params = @{@"mod": @"viewthread",
                                 @"mobile": @"no",
                                 @"tid": topicID};
        [self.client GET:url parameters:params success:success failure:failure];
    } else {
        NSDictionary *params = @{@"mod": @"viewthread",
                                 @"mobile": @"no",
                                 @"tid": topicID,
                                 @"page": page};
        [self.client GET:url parameters:params success:success failure:failure];
    }
}

- (void)requestTopicContentAPIForID:(NSNumber *)topicID
                        withPage:(NSNumber *)page
                         success:(void (^)(NSURLSessionDataTask *, id))success
                         failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *url = @"api/mobile/index.php";
    NSDictionary *params = @{@"module": @"viewthread",
                             @"version": @1,
                             @"ppp": @30,
                             @"submodule": @"checkpost",
                             @"mobile": @"no",
                             @"tid": topicID,
                             @"page": page};
    [[S1HTTPClient sharedJSONClient] GET:url parameters:params success:success failure:failure];
}


- (void)requestReplyRefereanceContentForTopicID:(NSNumber *)topicID
                                       withPage:(NSNumber *)page
                                        floorID:(NSNumber *)floorID
                                        fieldID:(NSNumber *)fieldID
                                        success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                                        failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    NSString *url = @"forum.php";
    NSDictionary *params = @{@"mod": @"post",
                             @"action": @"reply",
                             @"fid": fieldID,
                             @"tid": topicID,
                             @"repquote": floorID,
                             @"extra": @"",
                             @"page": page,
                             @"infloat": @"yes",
                             @"handlekey": @"reply",
                             @"inajax": @1,
                             @"ajaxtarget": @"fwin_content_reply"};
    [self.client GET:url parameters:params success:success failure:failure];
}

- (void)postReplyForTopicID:(NSNumber *)topicID
                   withPage:(NSNumber *)page
                    fieldID:(NSNumber *)fieldID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *, id))success
                    failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *urlTemplate = @"forum.php?mod=post&infloat=yes&action=reply&fid=%@&extra=page%%3D%@&tid=%@&replysubmit=yes&inajax=1";
    NSString *url = [NSString stringWithFormat:urlTemplate, fieldID, page, topicID];
    [self.client POST:url parameters:params success:success failure:failure];
}

- (void)postReplyForTopicID:(NSNumber *)topicID
                    fieldID:(NSNumber *)fieldID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *, id))success
                    failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *urlTemplate = @"forum.php?mod=post&action=reply&fid=%@&tid=%@&extra=page%%3D1&replysubmit=yes&infloat=yes&handlekey=fastpost&inajax=1";
    NSString *url = [NSString stringWithFormat:urlTemplate, fieldID, topicID];
    [self.client POST:url parameters:params success:success failure:failure];
}

+ (void)postLoginForUsername:(NSString *)username
                 andPassword:(NSString *)password
                     success:(void (^)(NSURLSessionDataTask *, id))success
                     failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *url = @"member.php?mod=logging&action=login&loginsubmit=yes&infloat=yes&lssubmit=yes&inajax=1";
    NSDictionary *params = @{@"fastloginfield" : @"username",
                            @"username" : username,
                            @"password" : password,
                            @"handlekey" : @"ls",
                            @"quickforward" : @"yes",
                            @"cookietime" : @"2592000"};
    [[S1HTTPClient sharedClient] POST:url parameters:params success:success failure:failure];
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
