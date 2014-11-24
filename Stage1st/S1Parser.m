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

#define kNumberPerPage 50

@interface S1Parser()
+ (NSString *)processImagesInHTMLString:(NSString *)HTMLString;
+ (NSString *)translateDateTimeString:(NSDate *)dateTime;
@end

@implementation S1Parser
+ (NSString *)processImagesInHTMLString:(NSString *)HTMLString
{
    DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:[HTMLString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
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
    NSString *processedString = [xmlDoc XMLStringWithOptions:DDXMLNodePrettyPrint];
    processedString = [processedString substringWithRange:NSMakeRange(183,[processedString length]-183-17)];
    if (processedString) {
        return [processedString stringByReplacingOccurrencesOfString:@"<br></br>" withString:@"<br />"];
    } else {
        NSLog(@"Report Fail to modify image");
        return HTMLString;
    }
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

+ (NSString *)preprocessAPIcontent:(NSString *)content {
    NSMutableString *mutableContent = [content mutableCopy];
    NSString *preprocessQuotePattern = @"<blockquote><p>引用:</p>";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:preprocessQuotePattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re replaceMatchesInString:mutableContent options:NSMatchingReportProgress range:NSMakeRange(0, [mutableContent length]) withTemplate:@"<blockquote>"];
    NSString *preprocessImagePattern = @"<imgwidth=([^>]*)>(\\[attach\\][\\d]*\\[/attach\\])?";
    re = [[NSRegularExpression alloc] initWithPattern:preprocessImagePattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re replaceMatchesInString:mutableContent options:NSMatchingReportProgress range:NSMakeRange(0, [mutableContent length]) withTemplate:@"<img width=$1>"];
    return mutableContent;
}

#pragma mark - Basic Parsing and Page Generating
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
        floor.floorID = rawFloor[@"pid"];
        floor.author = rawFloor[@"author"];
        floor.authorID = [NSNumber numberWithInteger:[rawFloor[@"authorid"] integerValue]];
        floor.indexMark = rawFloor[@"number"];
        floor.postTime = [NSDate dateWithTimeIntervalSince1970:[rawFloor[@"dbdateline"] doubleValue]];
        floor.content = [S1Parser preprocessAPIcontent:[NSString stringWithFormat:@"<td class=\"t_f\" id=\"postmessage_%@\">%@</td>", floor.floorID, rawFloor[@"message"]]];
        if ([rawFloor valueForKey:@"attachments"]!= nil) {
            NSMutableArray *imageAttachmentList = [[NSMutableArray alloc] init];
            for (NSNumber *attachmentKey in [rawFloor[@"attachments"] allKeys]) {
                NSString *imageURL = [rawFloor[@"attachments"][attachmentKey][@"url"] stringByAppendingString:rawFloor[@"attachments"][attachmentKey][@"attachment"]];
                NSString *imageNode = [NSString stringWithFormat:@"<img src=\"%@\" />", imageURL];
                [imageAttachmentList addObject:imageNode];
            }
            floor.imageAttachmentList = imageAttachmentList;
        }
        [floorList addObject:floor];
    }
    return floorList;
}

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
        NSString *floorPostTime = [self translateDateTimeString:topicFloor.postTime];
        
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
        NSString *contentString = [S1Parser processImagesInHTMLString:[NSString stringWithFormat:@"%@", topicFloor.content]];
        
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
            floorAttachment = [S1Parser processImagesInHTMLString:floorAttachment];
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
        cssPath = [[NSBundle mainBundle] pathForResource:@"content_ipad" ofType:@"css"];
    }
    NSString *jqueryPath = [[NSBundle mainBundle] pathForResource:@"jquery-2.1.1.min" ofType:@"js"];
    NSString *threadPage = [NSString stringWithFormat:threadTemplate, baseCSS, cssPath, jqueryPath, finalString];
    return threadPage;
}

#pragma mark - Pick Information
+ (NSString *)formhashFromThreadString:(NSString *)HTMLString
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

#pragma mark - Checking

+ (NSString *)loginUserName:(NSString *)HTMLString
{
    NSString *pattern = @"<strong class=\"vwmy\"><a[^>]*>([^<]*)</a></strong>";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:HTMLString options:NSMatchingReportProgress range:NSMakeRange(0, HTMLString.length)];
    NSString *username = [HTMLString substringWithRange:[result rangeAtIndex:1]];
    return [username isEqualToString:@""]?nil:username;
}

+ (NSNumber *)extractTopicIDFromLink:(NSString *)URLString
{
    NSString *pattern1 = [[[NSUserDefaults standardUserDefaults] stringForKey:@"BaseURL"] stringByAppendingString:@"thread-([0-9]+)-[0-9]+-[0-9]+\\.html"];
    NSRegularExpression *re1 = [[NSRegularExpression alloc] initWithPattern:pattern1 options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result1 = [re1 firstMatchInString:URLString options:NSMatchingReportProgress range:NSMakeRange(0, URLString.length)];
    NSString *topicIDString = [URLString substringWithRange:[result1 rangeAtIndex:1]];
    if ([topicIDString isEqualToString:@""]) {
        NSString *pattern2 = [[[NSUserDefaults standardUserDefaults] stringForKey:@"BaseURL"] stringByAppendingString:@"forum\\.php\\?mod=viewthread&tid=([0-9]+)"];
        NSRegularExpression *re2 = [[NSRegularExpression alloc] initWithPattern:pattern2 options:NSRegularExpressionAnchorsMatchLines error:nil];
        NSTextCheckingResult *result2 = [re2 firstMatchInString:URLString options:NSMatchingReportProgress range:NSMakeRange(0, URLString.length)];
        topicIDString = [URLString substringWithRange:[result2 rangeAtIndex:1]];
    }
    if ([topicIDString isEqualToString:@""]) {
        return nil;
    }
    return [NSNumber numberWithInteger:[topicIDString integerValue]];
}


@end
