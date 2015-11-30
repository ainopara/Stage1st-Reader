//
//  S1Parser.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Parser.h"
#import "S1Topic.h"
#import "S1Floor.h"
#import "TFHpple.h"
#import "DDXML.h"
#import "DDXMLElementAdditions.h"
#import "GTMNSString+HTML.h"
#import "S1AppDelegate.h"


@interface S1Parser()
@end

@implementation S1Parser
# pragma mark - Process Data
+ (NSString *)processHTMLString:(NSString *)HTMLString
{
    DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:[HTMLString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    //process images
    NSArray *images = [xmlDoc nodesForXPath:@"//img" error:nil];
    NSInteger imageCount = 1;
    for (DDXMLElement *image in images) {
        NSString *imageSrc = [[image attributeForName:@"src"] stringValue];
        NSString *imageFile = [[image attributeForName:@"file"] stringValue];
        if (imageFile) {
            [image removeAttributeForName:@"src"];
            [image addAttributeWithName:@"src" stringValue:imageFile];
            
        }
        else if (imageSrc && (![imageSrc hasPrefix:@"http"])) {
            [image removeAttributeForName:@"src"];
            NSString *baseURLString = [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"];
            [image addAttributeWithName:@"src" stringValue:[baseURLString stringByAppendingString:imageSrc]];
        }
        if ([[image attributeForName:@"src"] stringValue]) {
            if (![imageSrc hasPrefix:@"static/image/smiley"]) {
                DDXMLElement *linkElement = image;
                DDXMLElement *imageElement = [[DDXMLElement alloc] initWithName:@"img"];
                [imageElement addAttributeWithName:@"id" stringValue:[NSString stringWithFormat:@"img%ld", (long)imageCount]];
                imageCount += 1;
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Display"] || [MyAppDelegate.reachability isReachableViaWiFi]) {
                    [imageElement addAttributeWithName:@"src" stringValue:[[image attributeForName:@"src"] stringValue]];
                } else {
                    NSString *placeholderURL = [[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] stringByAppendingString:@"stage1streader-placeholder.png"];
                    [imageElement addAttributeWithName:@"src" stringValue:placeholderURL];
                }
                NSString *linkString = [NSString stringWithFormat:@"/present-image:%@#%@", [[image attributeForName:@"src"] stringValue], [[imageElement attributeForName:@"id"] stringValue]];
                [linkElement addAttributeWithName:@"href" stringValue:linkString];
                [linkElement addChild:imageElement];
                [linkElement removeAttributeForName:@"src"];
                [linkElement setName:@"a"];
            }
        }
        
        //clean image's attribute (if it is not a mahjong face, it is the linkElement)
        [image removeAttributeForName:@"onmouseover"];
        [image removeAttributeForName:@"onclick"];
        [image removeAttributeForName:@"file"];
        [image removeAttributeForName:@"id"];
        [image removeAttributeForName:@"lazyloadthumb"];
        [image removeAttributeForName:@"border"];
        [image removeAttributeForName:@"width"];
        [image removeAttributeForName:@"height"];
        
    }
    
    //process spoiler
    NSArray<NSString *> *spoilerXpathList = @[@"//font[@color='LemonChiffon']",
                                              @"//font[@color='Yellow']",
                                              @"//font[@color='#fffacd']",
                                              @"//font[@color='#FFFFCC']",
                                              @"//font[@color='White']"];
     NSArray< DDXMLElement *> * _Nullable spoilers = @[];
    for (NSString *spoilerXpath in spoilerXpathList) {
        NSArray< DDXMLElement *> * _Nullable temp = [xmlDoc nodesForXPath:spoilerXpath error:nil];
        if (temp != nil) {
            spoilers = [spoilers arrayByAddingObjectsFromArray:temp];
        }
    }

    for (DDXMLElement *spoilerElement in spoilers) {
        [spoilerElement removeAttributeForName:@"color"];
        [spoilerElement setName:@"div"];
        [spoilerElement addAttributeWithName:@"style" stringValue:@"display:none;"];
        NSUInteger index = [spoilerElement index];
        DDXMLElement *parentElement = (DDXMLElement *)[spoilerElement parent];
        [spoilerElement detach];
        [parentElement setOwner: xmlDoc];
        DDXMLElement *containerElement = [[DDXMLElement alloc] initWithName:@"div"];
        DDXMLElement *buttonElement = [[DDXMLElement alloc] initWithName:@"input"];
        [buttonElement addAttributeWithName:@"value" stringValue:@"显示反白内容"];
        [buttonElement addAttributeWithName:@"type" stringValue:@"button"];
        [buttonElement addAttributeWithName:@"style" stringValue:@"width:80px;font-size:10px;margin:0px;padding:0px;"];
        [buttonElement addAttributeWithName:@"onclick" stringValue:@"var e = this.parentNode.getElementsByTagName('div')[0];e.style.display = '';e.style.border = '#aaa 1px solid';this.style.display = 'none';"];
        [containerElement addChild:buttonElement];
        [containerElement addChild:spoilerElement];
        [parentElement insertChild:containerElement atIndex:index];
    }
    
    
    NSString *processedString = [xmlDoc XMLStringWithOptions:DDXMLNodePrettyPrint];
    processedString = [processedString substringWithRange:NSMakeRange(183,[processedString length]-183-17)];
    if (processedString) {
        return [processedString stringByReplacingOccurrencesOfString:@"<br></br>" withString:@"<br />"];
    } else {
        NSLog(@"Report Fail to modify image");
        return HTMLString;
    }
}

+ (NSString *)stripTails:(NSString *)content {
    if (content == nil) {
        return nil;
    }
    NSMutableString *mutableContent = [content mutableCopy];
    NSString *tailPattern = @"((\\<br ?/>(&#13;)?\\n)*(——— 来自|----发送自 |——发送自|( |&nbsp;)*—— from )<a href[^>]*(stage1st-reader|s1-pluto|stage1\\.5j4m\\.com|126\\.am/S1Nyan)[^>]*>[^<]*</a>[^<]*)?((<br ?/>|<br></br>)<a href=\"misc\\.php\\?mod\\=mobile\"[^<]*</a>)?";
    [S1Global regexReplaceString:mutableContent matchPattern:tailPattern withTemplate:@""];
    return mutableContent;
}

+ (NSString *)translateDateTimeString:(NSDate *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    NSTimeInterval interval = -[date timeIntervalSinceNow];
    if (interval<60) {
        return @"刚刚";
    }
    if (interval<3600) {
        NSNumber *minutes = [[NSNumber alloc] initWithInt: (int)interval/60];
        return [NSString stringWithFormat: @"%@分钟前", minutes];
    }
    if (interval <3600*2) {
        return @"1小时前";
    }
    if (interval <3600*3) {
        return @"2小时前";
    }
    if (interval <3600*4) {
        return @"3小时前";
    }
    
    [formatter setDateFormat:@"yyyy-M-d"];
    if ([[formatter stringFromDate:date] isEqualToString:[formatter stringFromDate:[[NSDate alloc] initWithTimeIntervalSinceNow:0]]]) {
        [formatter setDateFormat:@"HH:mm"];
        return [formatter stringFromDate:date];
    }
    if ([[formatter stringFromDate:date] isEqualToString:[formatter stringFromDate:[[NSDate alloc] initWithTimeIntervalSinceNow:-3600*24]]]) {
        [formatter setDateFormat:@"昨天HH:mm"];
        return [formatter stringFromDate:date];
    }
    if ([[formatter stringFromDate:date] isEqualToString:[formatter stringFromDate:[[NSDate alloc] initWithTimeIntervalSinceNow:-3600*24*2]]]) {
        [formatter setDateFormat:@"前天HH:mm"];
        return [formatter stringFromDate:date];
    }
    
    [formatter setDateFormat:@"yyyy"];
    if ([[formatter stringFromDate:date] isEqualToString:[formatter stringFromDate:[[NSDate alloc] initWithTimeIntervalSinceNow:0]]]) {
        [formatter setDateFormat:@"M-d HH:mm"];
        return [formatter stringFromDate:date];
    }
    [formatter setDateFormat:@"yyyy-M-d HH:mm"];
    return [formatter stringFromDate:date];
}

+ (NSString *)preprocessAPIcontent:(NSString *)content withAttachments:(NSMutableDictionary *)attachments {
    NSMutableString *mutableContent = [content mutableCopy];
    //process message
    [S1Global regexReplaceString:mutableContent matchPattern:@"提示: <em>(.*?)</em>" withTemplate:@"<div class=\"s1-alert\">$1</div>"];
    //process quote string
    [S1Global regexReplaceString:mutableContent matchPattern:@"<blockquote><p>引用:</p>" withTemplate:@"<blockquote>"];
    //process imgwidth issue
    [S1Global regexReplaceString:mutableContent matchPattern:@"<imgwidth=([^>]*)>" withTemplate:@"<img width=$1>"];
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
+ (NSArray *)topicsFromHTMLData:(NSData *)rawData withContext:(NSDictionary *)context
{
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    NSArray *elements  = [xpathParser searchWithXPathQuery:@"//table[@id='threadlisttableid']//tbody"];
    NSMutableArray *topics = [NSMutableArray array];
    
    NSLog(@"Topic count: %lu",(unsigned long)[elements count]);
    if ([elements count]) {
        for (TFHppleElement *element in elements){
            if (![[element objectForKey:@"id"] hasPrefix:@"normal"]) {
                continue;
            }
            TFHpple *xpathParserForRow = [[TFHpple alloc] initWithHTMLData:[element.raw dataUsingEncoding:NSUTF8StringEncoding]];
            TFHppleElement *leftPart  = [[xpathParserForRow searchWithXPathQuery:@"//a[@class='s xst']"] firstObject];
            NSString *content = [leftPart text];
            NSString *href = [leftPart objectForKey:@"href"];
            TFHppleElement *rightPart = [[xpathParserForRow searchWithXPathQuery:@"//a[@class='xi2']"] firstObject];
            NSString *replyCount = [rightPart text];
            TFHppleElement *authorPart = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='by'][1]/cite/a"] firstObject];
            NSString *authorName = [authorPart text];
            NSString *authorSpaceHref = [authorPart objectForKey:@"href"];
            
            S1Topic *topic = [[S1Topic alloc] init];
            [topic setTopicID:[NSNumber numberWithInteger:[[[href componentsSeparatedByString:@"-"] objectAtIndex:1] integerValue]]];
            [topic setTitle:content];
            [topic setReplyCount:[NSNumber numberWithInteger:[replyCount integerValue]]];
            [topic setFID:[NSNumber numberWithInteger:[context[@"FID"] integerValue]]];
            [topic setAuthorUserID:[NSNumber numberWithInteger:[[[authorSpaceHref componentsSeparatedByString:@"-"] objectAtIndex:2] integerValue]]];
            [topic setAuthorUserName:authorName];
            [topics addObject:topic];
        }
    }

    return (NSArray *)topics;
}

+ (NSMutableArray *)topicsFromAPI:(NSDictionary *)responseDict {
    NSArray *rawTopicList = responseDict[@"Variables"][@"forum_threadlist"];
    NSMutableArray *topics = [[NSMutableArray alloc] init];
    for (NSDictionary *rawTopic in rawTopicList) {
        S1Topic *topic = [[S1Topic alloc] init];
        topic.topicID = [NSNumber numberWithInteger:[rawTopic[@"tid"] integerValue]];
        topic.title = [(NSString *)rawTopic[@"subject"] gtm_stringByUnescapingFromHTML];
        topic.replyCount = [NSNumber numberWithInteger:[rawTopic[@"replies"] integerValue]];
        topic.fID = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"forum"][@"fid"] integerValue]];
        topic.authorUserID = [NSNumber numberWithInteger:[rawTopic[@"authorid"] integerValue]];
        topic.authorUserName = rawTopic[@"author"];
        BOOL isStickThread = NO;
        for (NSInteger i = [rawTopicList indexOfObject:rawTopic]; i< rawTopicList.count; i++) {
            NSDictionary *theTopic = [rawTopicList objectAtIndex:i];
            if ([rawTopic[@"dblastpost"] integerValue] < [theTopic[@"dblastpost"] integerValue]) {
                isStickThread = YES;
                //NSLog(@"remove stick subject:%@", topic.title);
                break;
            }
        }
        if (isStickThread == NO) {
            [topics addObject:topic];
        }
    }
    return topics;
}

+ (NSArray *)topicsFromSearchResultHTMLData:(NSData *)rawData {
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    NSArray *elements  = [xpathParser searchWithXPathQuery:@"//div[@id='threadlist']/ul/li[@class='pbw']"];
    NSMutableArray *topics = [NSMutableArray array];
    
    NSLog(@"Topic count: %lu",(unsigned long)[elements count]);
    for (TFHppleElement *element in elements){
        TFHpple *xpathParserForRow = [[TFHpple alloc] initWithHTMLData:[element.raw dataUsingEncoding:NSUTF8StringEncoding]];
        NSArray *links = [xpathParserForRow searchWithXPathQuery:@"//a[@target='_blank']"];
        
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
        
        
        S1Topic *topic = [[S1Topic alloc] init];
        [topic setTopicID:topicID];
        [topic setTitle:titleString];
        [topic setReplyCount:replyCount];
        [topic setFID:fid];
        [topic setAuthorUserID:authorUserID];
        [topic setAuthorUserName:authorName];
        [topics addObject:topic];
    }
    return topics;
    
}
+ (NSArray *)topicsFromPersonalInfoHTMLData:(NSData *)rawData {
    DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:rawData options:0 error:nil];
    NSArray *topicNodes = [xmlDoc nodesForXPath:@"//div[@class='tl']//tr[not(@class)]" error:nil];
    NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
    for (DDXMLElement *topicNode in topicNodes) {
        DDXMLElement *topicFirstSection = [[topicNode nodesForXPath:@".//th/a" error:nil] firstObject];
        NSString *topicHref = [[topicFirstSection attributeForName:@"href"] stringValue];
        NSString *topicTitle = [topicFirstSection stringValue];
        NSLog(@"%@, %@", topicHref, topicTitle);
        S1Topic *topic = [S1Parser extractTopicInfoFromLink:topicHref];
        topic.title = topicTitle;
        
        DDXMLElement *topicSecondSection = [[topicNode nodesForXPath:@".//a[@class='xg1']" error:nil] firstObject];
        NSString *topicForumIDString = [[topicSecondSection attributeForName:@"href"] stringValue];
        NSNumber *topicForumID = [NSNumber numberWithInteger:[[[S1Global regexExtractFromString:topicForumIDString withPattern:@"forum-([0-9]+)" andColums:@[@1]] firstObject] integerValue]];
        topic.fID = topicForumID;
        DDXMLElement *topicThirdSection = [[topicNode nodesForXPath:@".//a[@class='xi2']" error:nil] firstObject];
        NSNumber *topicReplyCount = [NSNumber numberWithInteger:[[topicThirdSection stringValue] integerValue]];
        NSLog(@"%@, %@", topicForumIDString, topicReplyCount);
        topic.replyCount = topicReplyCount;
        [mutableArray addObject:topic];
    }
    return mutableArray;
}

+ (NSArray *) contentsFromHTMLData:(NSData *)rawData
{
    // NSLog(@"Begin Parsing.");
    // NSDate *start = [NSDate date];
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    NSArray *elements  = [xpathParser searchWithXPathQuery:@"//div[@id='postlist']/div"];

    NSMutableArray *floorList = [[NSMutableArray alloc] init];
    // NSLog(@"Floor count: %lu",(unsigned long)[elements count]);
    
    if ([elements count]) {

        for (TFHppleElement *element in elements){
            if (![[element objectForKey:@"id"] hasPrefix:@"post_"]) {
                continue;
            }
            S1Floor *floor = [[S1Floor alloc] init];
            TFHpple *xpathParserForRow = [[TFHpple alloc] initWithHTMLData:[element.raw dataUsingEncoding:NSUTF8StringEncoding]];
            
            //parse author
            TFHppleElement *authorNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='pls']//div[@class='authi']/a"] firstObject];
            [floor setAuthor: [authorNode text]];
            [floor setAuthorID:[NSNumber numberWithInteger:[[[[authorNode objectForKey:@"href"] componentsSeparatedByString:@"-"] objectAtIndex:2] integerValue]]];
            
            //parse post time
            TFHppleElement *postTimeNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//div/em/span"] firstObject];
            NSString *dateTimeString;
            if (postTimeNode) {
                dateTimeString = [postTimeNode objectForKey:@"title"];
            } else {
                postTimeNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//div/em"] firstObject];
                dateTimeString  = [postTimeNode text];
            }
            if ([dateTimeString hasPrefix:@"发表于 "]) {
                dateTimeString = [dateTimeString stringByReplacingOccurrencesOfString:@"发表于 " withString:@""];
            }
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-M-d HH:mm:ss"];
            NSDate *date = [formatter dateFromString:dateTimeString];
            [floor setPostTime:date];
            
            //parse index mark
            TFHppleElement *floorIndexMarkNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']/div/strong/a"] firstObject];
            if ([[floorIndexMarkNode childrenWithTagName:@"em"] count] != 0) {
                [floor setIndexMark: [[floorIndexMarkNode firstChildWithTagName:@"em"] text]];
            } else {
                [floor setIndexMark: [[floorIndexMarkNode text] stringByReplacingOccurrencesOfString:@"\r\n" withString:@""]];
            }
            
            //parse poll
            //TFHppleElement *floorPollNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//form[@id='poll']"] firstObject];
            //[floor setPoll: [floorPollNode raw]];
            
            //parse message
            TFHppleElement *messageNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//div[@class='pcb']/div[@class='locked']/em"] firstObject];
            [floor setMessage: [messageNode text]];

            //parse content & floorID
            TFHppleElement *floorContentNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//td[@class='t_f']"] firstObject];
            [floor setContent: [floorContentNode raw]];
            NSString *floorIDString = [[floorContentNode objectForKey:@"id"] stringByReplacingOccurrencesOfString:@"postmessage_" withString:@""];
            [floor setFloorID:[NSNumber numberWithInteger: [floorIDString integerValue]]];
            
            //parse attachment
            NSArray *floorAttachmentArray = [xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//div[@class='mbn savephotop']/img"];
            if ([floorAttachmentArray count]) {
                NSMutableArray *imageAttachmentList = [[NSMutableArray alloc] init];
                for (TFHppleElement * floorAttachmentNode in floorAttachmentArray){
                    [imageAttachmentList addObject:[floorAttachmentNode raw]];
                }
                [floor setImageAttachmentList:imageAttachmentList];
            }

            [floorList addObject:floor];
        }
    }
    
    return floorList;
}



+ (NSArray *)contentsFromAPI:(NSDictionary *)responseDict {
    NSArray *rawFloorList = responseDict[@"Variables"][@"postlist"];
    NSMutableArray *floorList = [[NSMutableArray alloc] init];
    for (NSDictionary *rawFloor in rawFloorList) {
        S1Floor *floor = [[S1Floor alloc] init];
        NSMutableDictionary *attachments = nil;
        if ([rawFloor valueForKey:@"attachments"]!= nil) {
            attachments = [rawFloor[@"attachments"] mutableCopy];
        }
        floor.floorID = [NSNumber numberWithInteger:[rawFloor[@"pid"] integerValue]];
        floor.author = rawFloor[@"author"];
        floor.authorID = [NSNumber numberWithInteger:[rawFloor[@"authorid"] integerValue]];
        floor.indexMark = rawFloor[@"number"];
        floor.postTime = [NSDate dateWithTimeIntervalSince1970:[rawFloor[@"dbdateline"] doubleValue]];
        floor.content = [S1Parser preprocessAPIcontent:[NSString stringWithFormat:@"<td class=\"t_f\" id=\"postmessage_%@\">%@</td>", floor.floorID, rawFloor[@"message"]] withAttachments:attachments];
        floor.firstQuoteReplyFloorID = [S1Parser firstQuoteReplyFloorIDFromFloorString:floor.content];
        //process attachments left.
        if (attachments != nil && [attachments count] > 0) {
            NSMutableArray *imageAttachmentList = [[NSMutableArray alloc] init];
            for (NSNumber *attachmentKey in [attachments allKeys]) {
                NSString *imageURL = [attachments[attachmentKey][@"url"] stringByAppendingString:attachments[attachmentKey][@"attachment"]];
                NSString *imageNode = [NSString stringWithFormat:@"<img src=\"%@\" />", imageURL];
                [imageAttachmentList addObject:imageNode];
            }
            floor.imageAttachmentList = imageAttachmentList;
        }
        [floorList addObject:floor];
    }
    return floorList;
}

+ (NSString *)renderColorCSS {
    NSString *CSSTemplatePath = [[NSBundle mainBundle] pathForResource:@"color" ofType:@"css"];
    NSData *CSSTemplateData = [NSData dataWithContentsOfFile:CSSTemplatePath];
    NSString *CSSTemplate = [[NSString alloc] initWithData:CSSTemplateData  encoding:NSUTF8StringEncoding];
    CSSTemplate = [CSSTemplate stringByReplacingOccurrencesOfString:@"{{background}}" withString:[[APColorManager sharedInstance] htmlColorStringWithID:@"5"]];
    CSSTemplate = [CSSTemplate stringByReplacingOccurrencesOfString:@"{{text}}" withString:[[APColorManager sharedInstance] htmlColorStringWithID:@"21"]];
    CSSTemplate = [CSSTemplate stringByReplacingOccurrencesOfString:@"{{border}}" withString:[[APColorManager sharedInstance] htmlColorStringWithID:@"14"]];
    CSSTemplate = [CSSTemplate stringByReplacingOccurrencesOfString:@"{{borderText}}" withString:[[APColorManager sharedInstance] htmlColorStringWithID:@"17"]];
    return CSSTemplate;
}


#pragma mark - Page Generating
+ (NSString *)generateContentPage:(NSArray *)floorList withTopic:(S1Topic *)topic
{
    NSString *finalString = [[NSString alloc] init];
    for (S1Floor *topicFloor in floorList) {
        //process indexmark
        NSString *floorIndexMark = topicFloor.indexMark;
        if (![floorIndexMark isEqualToString:@"楼主"]) {
            floorIndexMark = [@"#" stringByAppendingString:topicFloor.indexMark];
        }
        
        //process author
        NSString *floorAuthor = topicFloor.author;
        if (topic.authorUserID && [topic.authorUserID isEqualToNumber:topicFloor.authorID] && ![floorIndexMark isEqualToString:@"楼主"]) {
            floorAuthor = [floorAuthor stringByAppendingString:@" (楼主)"];
        }
        
        //process time
        NSString *floorPostTime = [S1Parser translateDateTimeString:topicFloor.postTime];
        
        //process reply Button
        NSString *replyLinkString = @"";
        if ([[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"]) {
            replyLinkString = [NSString stringWithFormat: @"<div class=\"reply\"><a href=\"/reply?%@\">回复</a></div>" ,topicFloor.indexMark];
        }
        
        //process poll
        NSString *pollContentString = @"";
        if (topicFloor.poll != nil) {
            pollContentString = [NSString stringWithFormat:@"<div class=\"s1-poll\">%@</div>",topicFloor.poll];
        }
        
        //process content
        NSString *contentString = topicFloor.content;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"RemoveTails"]) {
            contentString = [S1Parser stripTails:contentString];
        }
        
        //work when the floor's author is blocked and s1reader using parse mode
        if (contentString == nil && topicFloor.message != nil) {
            contentString = [NSString stringWithFormat:@"<td class=\"t_f\"><div class=\"s1-alert\">%@</div></td>", topicFloor.message];
        }
        
        //process attachment
        NSString *floorAttachment = @"";
        if (topicFloor.imageAttachmentList) {
            for (NSString *imageURLString in topicFloor.imageAttachmentList) {
                NSString *processedImageURLString = [[NSString alloc] initWithString:imageURLString];
                if ([topicFloor.imageAttachmentList indexOfObject:imageURLString] != 0) {
                    processedImageURLString = [@"<br /><br />" stringByAppendingString:imageURLString];
                }
                floorAttachment = [floorAttachment stringByAppendingString:processedImageURLString];
            }
            floorAttachment = [NSString stringWithFormat:@"<div class='attachment'>%@</div>", floorAttachment];
        }
        
        //generate page
        NSString *floorTemplatePath = [[NSBundle mainBundle] pathForResource:@"FloorTemplate" ofType:@"html"];
        NSData *floorTemplateData = [NSData dataWithContentsOfFile:floorTemplatePath];
        NSString *floorTemplate = [[NSString alloc] initWithData:floorTemplateData  encoding:NSUTF8StringEncoding];
        
        NSString *output = [NSString stringWithFormat:floorTemplate, floorIndexMark, floorAuthor, floorPostTime, replyLinkString, pollContentString, contentString, floorAttachment];
        
        if ([floorList indexOfObject:topicFloor] != 0) {
            output = [@"<br />" stringByAppendingString:output];
        }
        finalString = [finalString stringByAppendingString:output];
    }
    finalString = [S1Parser processHTMLString:finalString];
    NSString *threadTemplatePath = [[NSBundle mainBundle] pathForResource:@"ThreadTemplate" ofType:@"html"];
    NSData *threadTemplateData = [NSData dataWithContentsOfFile:threadTemplatePath];
    NSString *threadTemplate = [[NSString alloc] initWithData:threadTemplateData  encoding:NSUTF8StringEncoding];
    //CSS
    NSString *baseCSS = [[NSBundle mainBundle] pathForResource:@"content_base" ofType:@"css"];
    NSString *cssPath = nil;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        NSString *fontSizeKey = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
        if ([fontSizeKey isEqualToString:@"15px"]) {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_15px" ofType:@"css"];
        } else if ([fontSizeKey isEqualToString:@"17px"]){
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_17px" ofType:@"css"];
        } else {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_19px" ofType:@"css"];
        }
    } else {
        NSString *fontSizeKey = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
        if ([fontSizeKey isEqualToString:@"18px"]) {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_ipad_18px" ofType:@"css"];
        } else if ([fontSizeKey isEqualToString:@"20px"]){
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_ipad_20px" ofType:@"css"];
        } else {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_ipad_22px" ofType:@"css"];
        }
    }
    NSString *colorCSS = [S1Parser renderColorCSS];
    NSString *jqueryPath = [[NSBundle mainBundle] pathForResource:@"jquery-2.1.1.min" ofType:@"js"];
    NSString *threadPage = [NSString stringWithFormat:threadTemplate, baseCSS, cssPath, colorCSS, jqueryPath, finalString];
    return threadPage;
}

+ (NSString *)generateQuotePage:(NSArray *)floorList withTopic:(S1Topic *)topic
{
    NSString *finalString = [[NSString alloc] init];
    for (S1Floor *topicFloor in floorList) {
        //process indexmark
        NSString *floorIndexMark = topicFloor.indexMark;
        if (![floorIndexMark isEqualToString:@"楼主"]) {
            floorIndexMark = [@"#" stringByAppendingString:topicFloor.indexMark];
        }
        
        //process author
        NSString *floorAuthor = topicFloor.author;
        if (topic.authorUserID && [topic.authorUserID isEqualToNumber:topicFloor.authorID] && ![floorIndexMark isEqualToString:@"楼主"]) {
            floorAuthor = [floorAuthor stringByAppendingString:@" (楼主)"];
        }
        
        //process time
        NSString *floorPostTime = [S1Parser translateDateTimeString:topicFloor.postTime];
        
        //process reply Button
        NSString *replyLinkString = @"";
        
        //process poll
        NSString *pollContentString = @"";
        
        //process content
        NSString *contentString = topicFloor.content;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"RemoveTails"]) {
            contentString = [S1Parser stripTails:contentString];
        }
        
        //work when the floor's author is blocked and s1reader using parse mode
        if (contentString == nil && topicFloor.message != nil) {
            contentString = [NSString stringWithFormat:@"<td class=\"t_f\"><div class=\"s1-alert\">%@</div></td>", topicFloor.message];
        }
        
        //process attachment
        NSString *floorAttachment = @"";
        if (topicFloor.imageAttachmentList) {
            for (NSString *imageURLString in topicFloor.imageAttachmentList) {
                NSString *processedImageURLString = [[NSString alloc] initWithString:imageURLString];
                if ([topicFloor.imageAttachmentList indexOfObject:imageURLString] != 0) {
                    processedImageURLString = [@"<br /><br />" stringByAppendingString:imageURLString];
                }
                floorAttachment = [floorAttachment stringByAppendingString:processedImageURLString];
            }
            floorAttachment = [NSString stringWithFormat:@"<div class='attachment'>%@</div>", floorAttachment];
        }
        
        //generate page
        NSString *floorTemplatePath = [[NSBundle mainBundle] pathForResource:@"FloorTemplate" ofType:@"html"];
        NSData *floorTemplateData = [NSData dataWithContentsOfFile:floorTemplatePath];
        NSString *floorTemplate = [[NSString alloc] initWithData:floorTemplateData  encoding:NSUTF8StringEncoding];
        
        NSString *output = [NSString stringWithFormat:floorTemplate, floorIndexMark, floorAuthor, floorPostTime, replyLinkString, pollContentString, contentString, floorAttachment];
        
        if ([floorList indexOfObject:topicFloor] != 0) {
            output = [@"<br />" stringByAppendingString:output];
        }
        finalString = [finalString stringByAppendingString:output];
    }
    finalString = [S1Parser processHTMLString:finalString];
    NSString *threadTemplatePath = [[NSBundle mainBundle] pathForResource:@"ThreadTemplate" ofType:@"html"];
    NSData *threadTemplateData = [NSData dataWithContentsOfFile:threadTemplatePath];
    NSString *threadTemplate = [[NSString alloc] initWithData:threadTemplateData  encoding:NSUTF8StringEncoding];
    //CSS
    NSString *baseCSS = [[NSBundle mainBundle] pathForResource:@"content_base" ofType:@"css"];
    NSString *cssPath = nil;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        NSString *fontSizeKey = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
        if ([fontSizeKey isEqualToString:@"15px"]) {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_15px" ofType:@"css"];
        } else if ([fontSizeKey isEqualToString:@"17px"]){
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_17px" ofType:@"css"];
        } else {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_19px" ofType:@"css"];
        }
    } else {
        NSString *fontSizeKey = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
        if ([fontSizeKey isEqualToString:@"18px"]) {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_ipad_18px" ofType:@"css"];
        } else if ([fontSizeKey isEqualToString:@"20px"]){
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_ipad_20px" ofType:@"css"];
        } else {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_ipad_22px" ofType:@"css"];
        }
    }
    NSString *colorCSS = [S1Parser renderColorCSS];
    NSString *jqueryPath = [[NSBundle mainBundle] pathForResource:@"jquery-2.1.1.min" ofType:@"js"];
    NSString *threadPage = [NSString stringWithFormat:threadTemplate, baseCSS, cssPath, colorCSS, jqueryPath, finalString];
    return threadPage;
}

#pragma mark - Pick Information

+ (S1Topic *)topicInfoFromThreadPage:(NSData *)rawData andPage:(NSNumber *)page{
    S1Topic *topic = [[S1Topic alloc] init];
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
    S1Topic *topic = [[S1Topic alloc] init];
    //Update Topic
    topic.title = [(NSString *)responseDict[@"Variables"][@"thread"][@"subject"] gtm_stringByUnescapingFromHTML];
    topic.authorUserID = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"thread"][@"authorid"] integerValue]];
    topic.authorUserName = responseDict[@"Variables"][@"thread"][@"author"];
    topic.formhash = responseDict[@"Variables"][@"formhash"];
    topic.replyCount = [NSNumber numberWithInteger:[responseDict[@"Variables"][@"thread"][@"replies"] integerValue]];
    double postPerPage = [responseDict[@"Variables"][@"ppp"] doubleValue];
    topic.totalPageCount = [NSNumber numberWithDouble: ceil( ([topic.replyCount doubleValue] + 1) / postPerPage )];
    topic.message = responseDict[@"Message"][@"messagestr"];
    return topic;
}


+ (NSString *)formhashFromPage:(NSString *)HTMLString
{
    NSString *pattern = @"name=\"formhash\" value=\"([0-9a-zA-Z]+)\"";
    return [[S1Global regexExtractFromString:HTMLString withPattern:pattern andColums:@[@1]] firstObject];
}

+ (NSUInteger)totalPagesFromThreadString:(NSString *)HTMLString
{
    NSArray *result = [S1Global regexExtractFromString:HTMLString withPattern:@"<span title=\"共 ([0-9]+) 页\">" andColums:@[@1]];
    if (result.count != 0) {
        return [((NSString *)[result firstObject]) integerValue];
    } else {
        return 1;
    }
}

+ (NSUInteger)replyCountFromThreadString:(NSString *)HTMLString
{
    NSArray *result = [S1Global regexExtractFromString:HTMLString withPattern:@"回复:</span> <span class=\"xi1\">([0-9]+)</span>" andColums:@[@1]];
    if (result.count != 0) {
        return [((NSString *)[result firstObject]) integerValue];
    } else {
        return 0;
    }
}

+ (NSMutableDictionary *)replyFloorInfoFromResponseString:(NSString *)ResponseString
{
    NSMutableDictionary *infoDict = [[NSMutableDictionary alloc] init];
    [infoDict setObject:@NO forKey:@"requestSuccess"];
    
    NSString *pattern = @"<input[^>]*name=\"([^>\"]*)\"[^>]*value=\"([^>\"]*)\"";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSArray *results = [re matchesInString:ResponseString options:NSMatchingReportProgress range:NSMakeRange(0, ResponseString.length)];
    if ([results count]) {
        [infoDict setObject:@YES forKey:@"requestSuccess"];
    }
    for (NSTextCheckingResult *result in results) {
        NSString *key = [ResponseString substringWithRange:[result rangeAtIndex:1]];
        NSString *value = [ResponseString substringWithRange:[result rangeAtIndex:2]];
        [infoDict setObject:value forKey:key];
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

+ (NSString *)loginUserName:(NSString *)HTMLString
{
    NSString *username = [[S1Global regexExtractFromString:HTMLString withPattern:@"<strong class=\"vwmy\"><a[^>]*>([^<]*)</a></strong>" andColums:@[@1]] firstObject];
    return [username isEqualToString:@""]?nil:username;
}

+ (NSNumber *)firstQuoteReplyFloorIDFromFloorString:(NSString *)floorString {
    NSString *urlString = [[S1Global regexExtractFromString:floorString withPattern:@"<div class=\"quote\"><blockquote><a href=\"([^\"]*)\"" andColums:@[@1]] firstObject];
    //NSLog(@"First Quote URL: %@",urlString);
    if (urlString) {
        NSDictionary *resultDict = [S1Parser extractQuerysFromURLString:[urlString gtm_stringByUnescapingFromHTML]];
        return [NSNumber numberWithInteger:[resultDict[@"pid"] integerValue]];
    }
    return nil;
}


#pragma mark - Extract From Link
+ (S1Topic *)extractTopicInfoFromLink:(NSString *)URLString
{
    S1Topic *topic = [[S1Topic alloc] init];
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
        NSDictionary *dict = [S1Parser extractQuerysFromURLString:URLString];
        topicIDString = [dict objectForKey:@"tid"];
        topicPageString = [dict objectForKey:@"page"];
        if (topicPageString == nil) {
            topicPageString = @"1";
        }
    }
    if (topicIDString == nil || [topicIDString isEqualToString:@""]) {
        return nil;
    }
    topic.topicID = [NSNumber numberWithInteger:[topicIDString integerValue]];
    topic.lastViewedPage = [NSNumber numberWithInteger:[topicPageString integerValue]];
    NSLog(@"%@", topic);
    return topic;
}

+ (NSDictionary *)extractQuerysFromURLString:(NSString *)URLString {
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
