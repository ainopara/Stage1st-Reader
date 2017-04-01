//
//  S1NetworkManager.m
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1NetworkManager.h"
#import "S1HTTPSessionManager.h"
#import <AFNetworking/AFURLRequestSerialization.h>

@interface S1NetworkManager ()

@property (nonatomic, strong) S1HTTPSessionManager *jsonClient;
@property (nonatomic, strong) S1HTTPSessionManager *httpClient;

@end

@implementation S1NetworkManager


- (instancetype)initWithBaseURL:(NSString *)baseURL
{
    self = [super init];

    if (self != nil) {
        _jsonClient = [[S1HTTPSessionManager alloc] initToJSONClientWithBaseURL:baseURL];
        _httpClient = [[S1HTTPSessionManager alloc] initToHTTPClientWithBaseURL:baseURL];
    }

    return self;
}

#pragma mark - Topic List

- (void)requestTopicListAPIForKey:(NSString *)keyID
                         withPage:(NSNumber *)page
                          success:(void (^)(NSURLSessionDataTask *, id))success
                          failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *url = @"api/mobile/index.php";
    NSDictionary *params = @{@"module": @"forumdisplay",
                             @"version": @1,
                             @"tpp": @50,
                             @"submodule": @"checkpost",
                             @"mobile": @"no",
                             @"fid": keyID,
                             @"page": page,
                             @"orderby": @"dblastpost"};
    [self.jsonClient GET:url parameters:params progress:nil success:success failure:failure];
    
}

#pragma mark - Content

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
    DDLogDebug(@"[Network] Request Topic Content API:%@-%@",topicID, page);
    [self.jsonClient GET:url parameters:params progress:nil success:success failure:failure];
}

#pragma mark - Check Login State

- (void)checkLoginStateAPIwithSuccessBlock:(void (^)(NSURLSessionDataTask *, id))success
                              failureBlock:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *url = @"api/mobile/";
    NSDictionary *params = @{@"module": @"login"};
    [self.jsonClient GET:url parameters:params progress:nil success:success failure:failure];
    
}

#pragma mark - Reply

- (void)requestReplyRefereanceContentForTopicID:(NSNumber *)topicID
                                       withPage:(NSNumber *)page
                                        floorID:(NSNumber *)floorID
                                        forumID:(NSNumber *)forumID
                                        success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                                        failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    NSString *url = @"forum.php";
    NSDictionary *params = @{@"mod": @"post",
                             @"action": @"reply",
                             @"fid": forumID,
                             @"tid": topicID,
                             @"repquote": floorID,
                             @"extra": @"",
                             @"page": page,
                             @"infloat": @"yes",
                             @"handlekey": @"reply",
                             @"inajax": @1,
                             @"ajaxtarget": @"fwin_content_reply"};
    [self.httpClient GET:url parameters:params progress:nil success:success failure:failure];
}

- (void)postReplyForTopicID:(NSNumber *)topicID
                   withPage:(NSNumber *)page
                    forumID:(NSNumber *)forumID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *, id))success
                    failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *urlTemplate = @"forum.php?mod=post&infloat=yes&action=reply&fid=%@&extra=page%%3D%@&tid=%@&replysubmit=yes&inajax=1";
    NSString *url = [NSString stringWithFormat:urlTemplate, forumID, page, topicID];
    [self.httpClient POST:url parameters:params progress:nil success:success failure:failure];
}

- (void)postReplyForTopicID:(NSNumber *)topicID
                    forumID:(NSNumber *)forumID
                  andParams:(NSDictionary *)params
                    success:(void (^)(NSURLSessionDataTask *, id))success
                    failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *urlTemplate = @"forum.php?mod=post&action=reply&fid=%@&tid=%@&extra=page%%3D1&replysubmit=yes&infloat=yes&handlekey=fastpost&inajax=1";
    NSString *url = [NSString stringWithFormat:urlTemplate, forumID, topicID];
    [self.httpClient POST:url parameters:params progress:nil success:success failure:failure];
}

#pragma mark - Redirect (Not Finish)

- (void)findTopicFloor:(NSNumber *)floorID
             inTopicID:(NSNumber *)topicID
               success:(void (^)(NSURLSessionDataTask *, id))success
               failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    NSString *url = @"forum.php";
    NSDictionary *params = @{@"mod" : @"redirect",
                             @"goto" : @"findpost",
                             @"pid" : floorID,
                             @"ptid" : topicID};
    [self.httpClient setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest *(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request) {
        DDLogDebug(@"%@",response);
        DDLogDebug(@"%@",request);
        if (request.URL) {
            ;
        }
        return request;
    }];
    [self.httpClient GET:url parameters:params progress:nil success:success failure:failure];
}


#pragma mark - Search

- (void)postSearchForKeyword:(NSString *)keyword
                 andFormhash:(NSString *)formhash
                     success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                     failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    if (formhash == nil) { return; }
    NSString *url = @"search.php?searchsubmit=yes";
    NSDictionary *params = @{@"mod" : @"forum",
                             @"formhash" : formhash,
                             @"srchtype" : @"title",
                             @"srhfid" : @"",
                             @"srhlocality" : @"forum::index",
                             @"srchtxt" : keyword,
                             @"searchsubmit" : @"true"};
    [self.httpClient POST:url parameters:params progress:nil success:success failure:failure];
}
//http://bbs.stage1.cc/search.php?mod=forum&searchid=706&orderby=lastpost&ascdesc=desc&searchsubmit=yes&page=2
- (void)requestSearchResultPageForSearchID:(NSString *)searchID
                                  withPage:(NSNumber *)page
                                   success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                                   failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    NSString *url = @"search.php";
    NSDictionary *params = @{@"mod" : @"forum",
                             @"searchid" : searchID,
                             @"orderby" : @"lastpost",
                             @"ascdesc" : @"desc",
                             @"page" : page,
                             @"searchsubmit" : @"yes"};
    [self.httpClient GET:url parameters:params progress:nil success:success failure:failure];
}

#pragma mark - User Info

- (void)requestThreadListForID:(NSNumber *)userID
                       andPage:(NSNumber *)page
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    NSString *url = @"home.php";
    NSDictionary *params = @{@"mod" : @"space",
                             @"uid" : userID,
                             @"do" : @"thread",
                             @"view" : @"me",
                             @"from" : @"space",
                             @"type" : @"thread",
                             @"page" : page,
                             @"order" : @"dateline"};
    [self.httpClient GET:url parameters:params progress:nil success:success failure:failure];
}

- (void)requestReplyListForID:(NSNumber *)userID
                      andPage:(NSNumber *)page
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    NSString *url = @"home.php";
    NSDictionary *params = @{@"mod" : @"space",
                             @"uid" : userID,
                             @"do" : @"thread",
                             @"view" : @"me",
                             @"from" : @"space",
                             @"type" : @"reply",
                             @"page" : page,
                             @"order" : @"dateline"};
    [self.httpClient GET:url parameters:params progress:nil success:success failure:failure];
}

#pragma mark - Cancel

- (void)cancelRequest
{
    [[self.httpClient session] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        // DDLogDebug(@"%lu,%lu,%lu",(unsigned long)dataTasks.count, (unsigned long)uploadTasks.count, (unsigned long)downloadTasks.count);
        for (NSURLSessionDataTask* task in downloadTasks) {
            [task cancel];
        }
        for (NSURLSessionDataTask* task in dataTasks) {
            [task cancel];
        }
    }];
    
    [[self.jsonClient session] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        // DDLogDebug(@"%lu,%lu,%lu",(unsigned long)dataTasks.count, (unsigned long)uploadTasks.count, (unsigned long)downloadTasks.count);
        for (NSURLSessionDataTask* task in downloadTasks) {
            [task cancel];
        }
        for (NSURLSessionDataTask* task in dataTasks) {
            [task cancel];
        }
    }];
}

@end
