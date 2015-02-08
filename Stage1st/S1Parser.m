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
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Display"]) {
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
    NSArray *spoilers = [xmlDoc nodesForXPath:@"//font[@color='LemonChiffon']" error:nil];
    spoilers = [spoilers arrayByAddingObjectsFromArray:[xmlDoc nodesForXPath:@"//font[@color='Yellow']" error:nil]];
    spoilers = [spoilers arrayByAddingObjectsFromArray:[xmlDoc nodesForXPath:@"//font[@color='White']" error:nil]];
    for (DDXMLElement *spoilerElement in spoilers) {
        [spoilerElement removeAttributeForName:@"color"];
        [spoilerElement setName:@"div"];
        [spoilerElement addAttributeWithName:@"style" stringValue:@"display:none;"];
        NSUInteger index = [spoilerElement index];
        DDXMLElement *parentElement = (DDXMLElement *)[spoilerElement parent];
        [spoilerElement detach];
        
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
    NSString *tailPattern = @"((\\<br ?/>(&#13;)?\\n)*(——— 来自|----发送自 |——发送自|    —— from )<a href[^>]*(stage1st-reader|s1-pluto|stage1\\.5j4m\\.com|126\\.am/S1Nyan)[^>]*>[^<]*</a>[^<]*)?((<br ?/>|<br></br>)<a href=\"misc\\.php\\?mod\\=mobile\"[^<]*</a>)?";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:tailPattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re replaceMatchesInString:mutableContent options:NSMatchingReportProgress range:NSMakeRange(0, [mutableContent length]) withTemplate:@""];
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
    NSString *preprocessMessagePattern = @"提示: <em>(.*?)</em>";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:preprocessMessagePattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re replaceMatchesInString:mutableContent options:NSMatchingReportProgress range:NSMakeRange(0, [mutableContent length]) withTemplate:@"<div class=\"s1-alert\">$1</div>"];
    //process quote string
    NSString *preprocessQuotePattern = @"<blockquote><p>引用:</p>";
    re = [[NSRegularExpression alloc] initWithPattern:preprocessQuotePattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re replaceMatchesInString:mutableContent options:NSMatchingReportProgress range:NSMakeRange(0, [mutableContent length]) withTemplate:@"<blockquote>"];
    //process imgwidth issue
    NSString *preprocessImagePattern = @"<imgwidth=([^>]*)>";
    re = [[NSRegularExpression alloc] initWithPattern:preprocessImagePattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re replaceMatchesInString:mutableContent options:NSMatchingReportProgress range:NSMakeRange(0, [mutableContent length]) withTemplate:@"<img width=$1>"];
    //process embeded image attachments
    __block NSString *finalString = [mutableContent copy];
    NSString *preprocessAttachmentImagePattern = @"\\[attach\\]([\\d]*)\\[/attach\\]";
    re = [[NSRegularExpression alloc] initWithPattern:preprocessAttachmentImagePattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
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
        NSString *pattern = @".*tid=([0-9]+).*";
        NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
        NSTextCheckingResult *result = [re firstMatchInString:URLString options:NSMatchingReportProgress range:NSMakeRange(0, URLString.length)];
        NSString *topicIDString = [URLString substringWithRange:[result rangeAtIndex:1]];
        NSNumber *topicID = [NSNumber numberWithInteger:[topicIDString integerValue]];
        
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
            TFHppleElement *floorPollNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//form[@id='poll']"] firstObject];
            [floor setPoll: [floorPollNode raw]];
            
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
        floor.floorID = rawFloor[@"pid"];
        floor.author = rawFloor[@"author"];
        floor.authorID = [NSNumber numberWithInteger:[rawFloor[@"authorid"] integerValue]];
        floor.indexMark = rawFloor[@"number"];
        floor.postTime = [NSDate dateWithTimeIntervalSince1970:[rawFloor[@"dbdateline"] doubleValue]];
        floor.content = [S1Parser preprocessAPIcontent:[NSString stringWithFormat:@"<td class=\"t_f\" id=\"postmessage_%@\">%@</td>", floor.floorID, rawFloor[@"message"]] withAttachments:attachments];
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
        contentString = [S1Parser stripTails:contentString];
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
    NSString *jqueryPath = [[NSBundle mainBundle] pathForResource:@"jquery-2.1.1.min" ofType:@"js"];
    NSString *threadPage = [NSString stringWithFormat:threadTemplate, baseCSS, cssPath, jqueryPath, finalString];
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
    topic.totalPageCount = [NSNumber numberWithDouble: ceil( [topic.replyCount doubleValue] / postPerPage )];
    topic.message = responseDict[@"Message"][@"messagestr"];
    return topic;
}


+ (NSString *)formhashFromPage:(NSString *)HTMLString
{
    NSString *pattern = @"name=\"formhash\" value=\"([0-9a-zA-Z]+)\"";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:HTMLString options:NSMatchingReportProgress range:NSMakeRange(0, HTMLString.length)];
    NSString *formhash = [HTMLString substringWithRange:[result rangeAtIndex:1]];
    return formhash;
}

+ (NSUInteger)totalPagesFromThreadString:(NSString *)HTMLString
{
    NSString *pattern = @"<span title=\"共 ([0-9]+) 页\">";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:HTMLString options:NSMatchingReportProgress range:NSMakeRange(0, HTMLString.length)];
    if (result) {
        return [[HTMLString substringWithRange:[result rangeAtIndex:1]] integerValue];
    } else {
        return 0;
    }
}

+ (NSUInteger)replyCountFromThreadString:(NSString *)HTMLString
{
    NSString *pattern = @"回复:</span> <span class=\"xi1\">([0-9]+)</span>";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:HTMLString options:NSMatchingReportProgress range:NSMakeRange(0, HTMLString.length)];
    if (result) {
        return [[HTMLString substringWithRange:[result rangeAtIndex:1]] integerValue];
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

#pragma mark - Checking

+ (NSString *)loginUserName:(NSString *)HTMLString
{
    NSString *pattern = @"<strong class=\"vwmy\"><a[^>]*>([^<]*)</a></strong>";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:HTMLString options:NSMatchingReportProgress range:NSMakeRange(0, HTMLString.length)];
    NSString *username = [HTMLString substringWithRange:[result rangeAtIndex:1]];
    return [username isEqualToString:@""]?nil:username;
}
#pragma mark - Extract Data
+ (S1Topic *)extractTopicInfoFromLink:(NSString *)URLString
{
    S1Topic *topic = [[S1Topic alloc] init];
    NSString *pattern1 = [[[NSUserDefaults standardUserDefaults] stringForKey:@"BaseURL"] stringByAppendingString:@"thread-([0-9]+)-([0-9]+)-[0-9]+\\.html"];
    NSRegularExpression *re1 = [[NSRegularExpression alloc] initWithPattern:pattern1 options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result1 = [re1 firstMatchInString:URLString options:NSMatchingReportProgress range:NSMakeRange(0, URLString.length)];
    NSString *topicIDString = [URLString substringWithRange:[result1 rangeAtIndex:1]];
    NSString *topicPageString = [URLString substringWithRange:[result1 rangeAtIndex:2]];
    if ([topicIDString isEqualToString:@""]) {
        NSString *pattern2 = @"forum\\.php\\?mod=viewthread&tid=([0-9]+)";
        NSRegularExpression *re2 = [[NSRegularExpression alloc] initWithPattern:pattern2 options:NSRegularExpressionAnchorsMatchLines error:nil];
        NSTextCheckingResult *result2 = [re2 firstMatchInString:URLString options:NSMatchingReportProgress range:NSMakeRange(0, URLString.length)];
        topicIDString = [URLString substringWithRange:[result2 rangeAtIndex:1]];
        topicPageString = @"1";
    }
    if ([topicIDString isEqualToString:@""]) {
        return nil;
    }
    topic.topicID = [NSNumber numberWithInteger:[topicIDString integerValue]];
    topic.lastViewedPage = [NSNumber numberWithInteger:[topicPageString integerValue]];
    return topic;
}



@end
