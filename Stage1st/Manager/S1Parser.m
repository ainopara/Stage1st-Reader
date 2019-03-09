//
//  S1Parser.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Parser.h"
#import "S1Topic.h"
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
        NSDictionary<NSString *, NSString *> *dict = [Parser extractQuerysFrom:URLString];
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

@end
