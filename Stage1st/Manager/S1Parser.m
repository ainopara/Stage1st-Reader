//
//  S1Parser.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Parser.h"
#import "S1Topic.h"
#import "TFHpple.h"
#import "DDXML.h"
#import "DDXMLElementAdditions.h"
#import "GTMNSString+HTML.h"

@implementation S1Parser

# pragma mark - Process Data

+ (NSString *)preprocessAPIcontent:(NSString *)content withAttachments:(NSMutableDictionary *)attachments {
    NSMutableString *mutableContent = [content mutableCopy];
    //process message
    [S1Global regexReplaceString:mutableContent matchPattern:@"提示: <em>(.*?)</em>" withTemplate:@"<div class=\"s1-alert\">$1</div>"];
    //process quote string
    [S1Global regexReplaceString:mutableContent matchPattern:@"<blockquote><p>引用:</p>" withTemplate:@"<blockquote>"];
    //process imgwidth issue
    [S1Global regexReplaceString:mutableContent matchPattern:@"<imgwidth=([^>]*)>" withTemplate:@"<img width=$1>"];
    // process embeded bilibili video to link
    [S1Global regexReplaceString:mutableContent matchPattern:@"\\[thgame_biliplay\\{,=av\\}(\\d+)\\{,=page\\}(\\d+)[^\\]]*\\]\\[/thgame_biliplay\\]" withTemplate:@"<a href=\"https://www.bilibili.com/video/av$1/index_$2.html\">https://www.bilibili.com/video/av$1/index_$2.html</a>"];
    //process embeded image attachments
    __block NSString *finalString = [mutableContent copy];
    NSString *preprocessAttachmentImagePattern = @"\\[attach\\]([\\d]*)\\[/attach\\]";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:preprocessAttachmentImagePattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re enumerateMatchesInString:mutableContent options:NSMatchingReportProgress range:NSMakeRange(0, [mutableContent length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result != nil && attachments != nil) {
            NSRange range = [result rangeAtIndex:1];
            NSString *attachmentID = [mutableContent substringWithRange:range];
            for (NSNumber *attachmentKey in [attachments allKeys]) {
                if ([attachmentKey integerValue] == [attachmentID integerValue]) {
                    NSString *imageURL = [attachments[attachmentKey][@"url"] stringByAppendingString:attachments[attachmentKey][@"attachment"]];
                    NSString *imageNode = [NSString stringWithFormat:@"<img src=\"%@\" />", imageURL];
                    finalString = [finalString stringByReplacingOccurrencesOfString:[NSString stringWithFormat: @"[attach]%@[/attach]", attachmentID] withString:imageNode];
                    [attachments removeObjectForKey:attachmentKey];
                    break;
                }
            }
        }
    }];
    
    return finalString;
}

#pragma mark - Page Parsing

+ (NSMutableArray<S1Topic *> *)topicsFromAPI:(NSDictionary *)responseDict {
    NSArray *rawTopicList = responseDict[@"Variables"][@"forum_threadlist"];
    NSMutableArray *topics = [[NSMutableArray alloc] init];
    for (NSDictionary *rawTopic in rawTopicList) {
        S1Topic *topic = [[S1Topic alloc] initWithTopicID:[NSNumber numberWithInteger:[rawTopic[@"tid"] integerValue]]];
        topic.title = [(NSString *)rawTopic[@"subject"] gtm_stringByUnescapingFromHTML];
        topic.replyCount = [NSNumber numberWithInteger:[rawTopic[@"replies"] integerValue]];
        topic.fID = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"forum"][@"fid"] integerValue]];
        topic.authorUserID = [NSNumber numberWithInteger:[rawTopic[@"authorid"] integerValue]];
        topic.authorUserName = rawTopic[@"author"];
        if (rawTopic[@"dblastpost"] != nil) {
            topic.lastReplyDate = [NSDate dateWithTimeIntervalSince1970:[rawTopic[@"dblastpost"] integerValue]];
        }

        BOOL isStickThread = NO;
        for (NSInteger i = [rawTopicList indexOfObject:rawTopic]; i< rawTopicList.count; i++) {
            NSDictionary *theTopic = [rawTopicList objectAtIndex:i];
            if ([rawTopic[@"dblastpost"] integerValue] < [theTopic[@"dblastpost"] integerValue]) {
                isStickThread = YES;
                //DDLogDebug(@"remove stick subject:%@", topic.title);
                break;
            }
        }
        if (isStickThread == NO || ![[NSUserDefaults standardUserDefaults] boolForKey:@"Stage1st_TopicList_HideStickTopics"]) {
            [topics addObject:topic];
        }
    }
    return topics;
}

+ (NSArray<S1Topic *> *)topicsFromSearchResultHTMLData:(NSData *)rawData {
    NSData *cleanedData = rawData;
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:cleanedData];
    NSArray<TFHppleElement *> *elements = [xpathParser searchWithXPathQuery:@"//div[@id='threadlist']/ul/li[@class='pbw']"];
    NSMutableArray<S1Topic *> *topics = [NSMutableArray array];
    
    DDLogDebug(@"[Parser] Search result topic count: %lu",(unsigned long)[elements count]);
    for (TFHppleElement *element in elements) {
        TFHpple *xpathParserForRow = [[TFHpple alloc] initWithHTMLData:[element.raw dataUsingEncoding:NSUTF8StringEncoding]];
        NSArray *links = [xpathParserForRow searchWithXPathQuery:@"//a[@target='_blank']"];
        if ([links count] != 3) continue;
        TFHppleElement *titlePart = [links firstObject];
        NSString *titleString = [titlePart recursionText];
        
        NSString *URLString = [titlePart objectForKey:@"href"];
        S1Topic *topicFromURL = [S1Parser extractTopicInfoFromLink:URLString];
        NSNumber *topicID = topicFromURL.topicID;
        
        TFHppleElement *authorPart = [links objectAtIndex:1];
        NSString *authorName = [authorPart text];
        NSString *authorSpaceHref = [authorPart objectForKey:@"href"];
        NSNumber *authorUserID = [NSNumber numberWithInteger:[[[authorSpaceHref componentsSeparatedByString:@"-"] objectAtIndex:2] integerValue]];
        
        TFHppleElement *fidPart = [links objectAtIndex:2];
        NSString *fidHref = [fidPart objectForKey:@"href"];
        NSNumber *fid = [NSNumber numberWithInteger:[[[fidHref componentsSeparatedByString:@"-"] objectAtIndex:1] integerValue]];
        
        TFHppleElement *replyCountPart = [[xpathParserForRow searchWithXPathQuery:@"//p[@class='xg1']"] firstObject];
        NSString *replyCountString = [[[replyCountPart text] componentsSeparatedByString:@" "] firstObject];
        NSNumber *replyCount = [NSNumber numberWithInteger:[replyCountString integerValue]];

        if (topicID != nil) {
            S1Topic *topic = [[S1Topic alloc] initWithTopicID:topicID];
            [topic setTitle:titleString];
            [topic setReplyCount:replyCount];
            [topic setFID:fid];
            [topic setAuthorUserID:authorUserID];
            [topic setAuthorUserName:authorName];
            [topics addObject:topic];
        }
    }

    NSString *searchID = nil;
    NSArray<TFHppleElement *> *nextPageLinks = [xpathParser searchWithXPathQuery:@"//div[@class='pg']/a[@class='nxt']/@href"];
    id rawNextPageURL = nextPageLinks.firstObject.firstTextChild.content;
    if (rawNextPageURL != nil && [rawNextPageURL isKindOfClass: [NSString class]]) {
        NSString *nextPageURL = rawNextPageURL;
        nextPageURL = [nextPageURL gtm_stringByUnescapingFromHTML];
        NSArray<NSURLQueryItem *> *queryItems = [[[NSURLComponents alloc] initWithString:nextPageURL] queryItems];
        for (NSURLQueryItem *item in queryItems) {
            if ([item.name isEqualToString:@"searchid"]) {
                searchID = item.value;
            }
        }
    }

    return topics;
}

+ (NSArray<S1Topic *> *)topicsFromPersonalInfoHTMLData:(NSData *)rawData {
    DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:rawData options:0 error:nil];
    NSArray<DDXMLElement *> *topicNodes = [xmlDoc nodesForXPath:@"//div[@class='tl']//tr[not(@class)]" error:nil];
    NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
    for (DDXMLElement *topicNode in topicNodes) {
        DDXMLElement *topicFirstSection = [[topicNode nodesForXPath:@".//th/a" error:nil] firstObject];
        NSString *topicHref = [[topicFirstSection attributeForName:@"href"] stringValue];
        NSString *topicTitle = [topicFirstSection stringValue];
        DDLogDebug(@"[Parser] href: %@, title: %@", topicHref, topicTitle);
        S1Topic *topic = [S1Parser extractTopicInfoFromLink:topicHref];
        topic.title = topicTitle;
        
        DDXMLElement *topicSecondSection = [[topicNode nodesForXPath:@".//a[@class='xg1']" error:nil] firstObject];
        NSString *topicForumIDString = [[topicSecondSection attributeForName:@"href"] stringValue];
        NSNumber *firstObject = [[S1Global regexExtractFromString:topicForumIDString withPattern:@"forum-([0-9]+)" andColums:@[@1]] firstObject];
        if (firstObject == nil) {
            continue;
        }
        NSNumber *topicForumID = [NSNumber numberWithInteger:[firstObject integerValue]];
        topic.fID = topicForumID;
        DDXMLElement *topicThirdSection = [[topicNode nodesForXPath:@".//a[@class='xi2']" error:nil] firstObject];
        NSNumber *topicReplyCount = [NSNumber numberWithInteger:[[topicThirdSection stringValue] integerValue]];
        DDLogDebug(@"[Parser] fid: %@, replyCount: %@", topicForumIDString, topicReplyCount);
        topic.replyCount = topicReplyCount;
        [mutableArray addObject:topic];
    }
    return mutableArray;
}

+ (NSArray *)contentsFromAPI:(NSDictionary *)responseDict {
    NSArray *rawFloorList = responseDict[@"Variables"][@"postlist"];
    NSMutableArray *floorList = [[NSMutableArray alloc] init];
    for (NSDictionary *rawFloor in rawFloorList) {
        Floor *floor = [[Floor alloc] initWithID:[rawFloor[@"pid"] integerValue] author:[[User alloc] initWithID:[rawFloor[@"authorid"] integerValue] name:rawFloor[@"author"]]];
        floor.indexMark = rawFloor[@"number"];
        floor.creationDate = [NSDate dateWithTimeIntervalSince1970:[rawFloor[@"dbdateline"] doubleValue]];
        NSMutableDictionary *attachments = nil;
        if ([rawFloor valueForKey:@"attachments"]!= nil) {
            attachments = [rawFloor[@"attachments"] mutableCopy];
        }
        floor.content = [S1Parser preprocessAPIcontent:[NSString stringWithFormat:@"<td class=\"t_f\" id=\"postmessage_%ld\">%@</td>", (long)floor.ID, rawFloor[@"message"]] withAttachments:attachments];
        //process attachments left.

        if (attachments != nil && [attachments count] > 0) {
            NSMutableArray *imageAttachmentList = [[NSMutableArray alloc] init];
            for (NSNumber *attachmentKey in [attachments allKeys]) {
                NSString *imageURL = [attachments[attachmentKey][@"url"] stringByAppendingString:attachments[attachmentKey][@"attachment"]];
                if (imageURL != nil) {
                    [imageAttachmentList addObject:imageURL];
                }
            }
            floor.imageAttachmentURLStringList = imageAttachmentList;
        }
        [floorList addObject:floor];
    }
    return floorList;
}

#pragma mark - Pick Information

+ (S1Topic *)topicInfoFromThreadPage:(NSData *)rawData page:(NSNumber *)page withTopicID:(NSNumber *)topicID {
    S1Topic *topic = [[S1Topic alloc] initWithTopicID:topicID];
    //update title
    NSString *title = [S1Parser topicTitleFromPage:rawData];
    if (title != nil) {
        topic.title = title;
    }
    
    //pick message
    topic.message = [S1Parser messageFromPage:rawData];
    
    // get formhash
    NSString* HTMLString = [[NSString alloc] initWithData:rawData encoding:NSUTF8StringEncoding];
    [topic setFormhash:[S1Parser formhashFromPage:HTMLString]];
    
    //set reply count
    if ([page isEqualToNumber:@1]) {
        NSInteger parsedReplyCount = [S1Parser replyCountFromThreadString:HTMLString];
        if (parsedReplyCount != 0) {
            [topic setReplyCount:[NSNumber numberWithInteger:parsedReplyCount]];
        }
    }

    // update total page
    NSInteger parsedTotalPages = [S1Parser totalPagesFromThreadString:HTMLString];
    if (parsedTotalPages != 0) {
        [topic setTotalPageCount:[NSNumber numberWithInteger:parsedTotalPages]];
    }
    return topic;
}

+ (S1Topic *)topicInfoFromAPI:(NSDictionary *)responseDict {
    NSNumber *topicID = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"thread"][@"tid"] integerValue]];
    if (topicID == nil || [topicID isEqualToNumber:@0]) {
        return nil;
    }
    S1Topic *topic = [[S1Topic alloc] initWithTopicID:topicID];
    //Update Topic
    topic.title = [(NSString *)responseDict[@"Variables"][@"thread"][@"subject"] gtm_stringByUnescapingFromHTML];
    topic.authorUserID = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"thread"][@"authorid"] integerValue]];
    topic.authorUserName = responseDict[@"Variables"][@"thread"][@"author"];
    topic.formhash = responseDict[@"Variables"][@"formhash"];
    topic.fID = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"fid"] integerValue]];
    topic.replyCount = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"thread"][@"replies"] integerValue]];
    double postPerPage = [responseDict[@"Variables"][@"ppp"] integerValue];
    topic.totalPageCount = [NSNumber numberWithInteger:([topic.replyCount integerValue] / postPerPage) + 1];
    topic.message = responseDict[@"Message"][@"messagestr"];
    return topic;
}


+ (NSString *)formhashFromPage:(NSString *)HTMLString {
    NSString *pattern = @"name=\"formhash\" value=\"([0-9a-zA-Z]+)\"";
    return [[S1Global regexExtractFromString:HTMLString withPattern:pattern andColums:@[@1]] firstObject];
}

+ (NSUInteger)totalPagesFromThreadString:(NSString *)HTMLString {
    NSArray *result = [S1Global regexExtractFromString:HTMLString withPattern:@"<span title=\"共 ([0-9]+) 页\">" andColums:@[@1]];
    if (result && result.count != 0) {
        return [((NSString *)[result firstObject]) integerValue];
    } else {
        return 1;
    }
}

+ (NSUInteger)replyCountFromThreadString:(NSString *)HTMLString {
    NSArray *result = [S1Global regexExtractFromString:HTMLString withPattern:@"回复:</span> <span class=\"xi1\">([0-9]+)</span>" andColums:@[@1]];
    if (result && result.count != 0) {
        return [((NSString *)[result firstObject]) integerValue];
    } else {
        return 0;
    }
}

+ (NSMutableDictionary *_Nullable)replyFloorInfoFromResponseString:(NSString *)responseString {
    NSMutableDictionary *infoDict = [[NSMutableDictionary alloc] init];
    if (responseString == nil) {
        return nil;
    }
    NSString *pattern = @"<input[^>]*name=\"([^>\"]*)\"[^>]*value=\"([^>\"]*)\"";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSArray *results = [re matchesInString:responseString options:NSMatchingReportProgress range:NSMakeRange(0, responseString.length)];
    if ([results count] == 0) {
        return nil;
    }
    for (NSTextCheckingResult *result in results) {
        NSString *key = [responseString substringWithRange:[result rangeAtIndex:1]];
        NSString *value = [responseString substringWithRange:[result rangeAtIndex:2]];
        if ([key isEqualToString:@"noticetrimstr"]) {
            [infoDict setObject:[value gtm_stringByUnescapingFromHTML] forKey:key];
        } else {
            [infoDict setObject:value forKey:key];
        }
    }
    return infoDict;
}

+ (NSString *)topicTitleFromPage:(NSData *)rawData {
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    TFHppleElement *element = [[xpathParser searchWithXPathQuery:@"//span[@id='thread_subject']"] firstObject];
    if (element) {
        return [element text];
    }
    return nil;
    
}

+ (NSString *)messageFromPage:(NSData *)rawData {
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    TFHppleElement *element = [[xpathParser searchWithXPathQuery:@"//div[@id='messagetext']/p"] firstObject];
    if (element) {
        return [element text];
    }
    return nil;
    
}

+ (NSString *)loginUserName:(NSString *)HTMLString {
    NSString *username = [[S1Global regexExtractFromString:HTMLString withPattern:@"<strong class=\"vwmy\"><a[^>]*>([^<]*)</a></strong>" andColums:@[@1]] firstObject];
    return [username isEqualToString:@""]?nil:username;
}

+ (NSNumber *)firstQuoteReplyFloorIDFromFloorString:(NSString *)floorString {
    NSString *urlString = [[S1Global regexExtractFromString:floorString withPattern:@"<div class=\"quote\"><blockquote><a href=\"([^\"]*)\"" andColums:@[@1]] firstObject];
    //DDLogDebug(@"First Quote URL: %@",urlString);
    if (urlString) {
        NSDictionary *resultDict = [S1Parser extractQuerysFromURLString:[urlString gtm_stringByUnescapingFromHTML]];
        return [NSNumber numberWithInteger:[resultDict[@"pid"] integerValue]];
    }
    return nil;
}

#pragma mark - Extract From Link

+ (S1Topic *)extractTopicInfoFromLink:(NSString *)URLString {
    // Current Html Scheme
    NSArray *result = [S1Global regexExtractFromString:URLString withPattern:@"thread-([0-9]+)-([0-9]+)-[0-9]+\\.html" andColums:@[@1,@2]];
    NSString *topicIDString = [result firstObject];
    NSString *topicPageString = [result lastObject];
    // Old Html Scheme
    if (topicIDString == nil || [topicIDString isEqualToString:@""]) {
        result = [S1Global regexExtractFromString:URLString withPattern:@"read-htm-tid-([0-9]+)\\.html" andColums:@[@1]];
        topicIDString = [result firstObject];
        topicPageString = @"1";
    }
    // Php Scheme
    if (topicIDString == nil || [topicIDString isEqualToString:@""]) {
        NSDictionary<NSString *, NSString *> *dict = [S1Parser extractQuerysFromURLString:URLString];
        topicIDString = [dict objectForKey:@"tid"];
        topicPageString = [dict objectForKey:@"page"];
        if (topicPageString == nil) {
            topicPageString = @"1";
        }
    }
    if (topicIDString == nil || [topicIDString isEqualToString:@""]) {
        return nil;
    }
    S1Topic *topic = [[S1Topic alloc] initWithTopicID:[NSNumber numberWithInteger:[topicIDString integerValue]]];
    topic.lastViewedPage = [NSNumber numberWithInteger:[topicPageString integerValue]];
    DDLogDebug(@"[Parser] Extract Topic: %@", topic);
    return topic;
}

+ (NSDictionary<NSString *, NSString *> *)extractQuerysFromURLString:(NSString *)URLString {
    NSURL *url = [[NSURL alloc] initWithString:URLString];
    if (url!= nil) {
        NSString *queryString = [url.query gtm_stringByUnescapingFromHTML];
        if (queryString != nil) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            for (NSString *component in [queryString componentsSeparatedByString:@"&"]) {
                NSArray *part = [component componentsSeparatedByString:@"="];
                if ([part count] == 2) {
                    [dict setObject:[part lastObject] forKey:[part firstObject]];
                }
            }
            return dict;
        }
    }
    return nil;
}

@end
