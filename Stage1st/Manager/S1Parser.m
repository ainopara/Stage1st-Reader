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
#import "GTMNSString+HTML.h"
#import "S1Global.h"
#import "Stage1st-Swift.h"

@implementation S1Parser

#pragma mark - Page Parsing

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

#pragma mark - Pick Information

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
