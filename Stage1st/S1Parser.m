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
+ (NSString *)translateDateTimeString:(NSString *)dateTimeString;
@end

@implementation S1Parser
+ (NSString *)processImagesInHTMLString:(NSString *)HTMLString
{
    DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:[HTMLString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSArray *images = [xmlDoc nodesForXPath:@"//img" error:nil];
    for (DDXMLElement *image in images) {
        NSString *imageSrc = [[image attributeForName:@"src"] stringValue];
        //NSLog(@"image Src:%@",imageSrc);
        NSString *imageFile = [[image attributeForName:@"file"] stringValue];
        //NSLog(@"image File:%@",imageFile);
        if (imageFile) {
            [image removeAttributeForName:@"src"];
            [image addAttributeWithName:@"src" stringValue:imageFile];
            [image removeAttributeForName:@"width"];
            [image removeAttributeForName:@"height"];
        }
        else if (imageSrc && (![imageSrc hasPrefix:@"http"])) {
            [image removeAttributeForName:@"src"];
            NSString *baseURLString = [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"];
            [image addAttributeWithName:@"src" stringValue:[baseURLString stringByAppendingString:imageSrc]];
        }
        
    }
    HTMLString = [xmlDoc XMLStringWithOptions:DDXMLNodePrettyPrint];
    HTMLString = [HTMLString stringByReplacingOccurrencesOfString:@"<br></br>" withString:@"<br />"];
    return HTMLString;
}

+ (NSString *)translateDateTimeString:(NSString *)dateTimeString
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-M-d HH:mm:ss"];
    NSDate *date = [formatter dateFromString:dateTimeString];
    NSTimeInterval interval = -[date timeIntervalSinceNow];
    if (interval<60) {
        return @"刚刚";
    }
    if (interval<3600) {
        [formatter setDateFormat:@"m分钟前"];
        return [formatter stringFromDate:date];
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
    
    [formatter setDateFormat:@"d"];
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
        [formatter setDateFormat:@"MM-dd HH:mm"];
        return [formatter stringFromDate:date];
    }
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    return [formatter stringFromDate:date];
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
            TFHppleElement *rightPart  = [[xpathParserForRow searchWithXPathQuery:@"//a[@class='xi2']"] firstObject];
            NSString *replyCount = [rightPart text];
            
            S1Topic *topic = [[S1Topic alloc] init];
            [topic setTopicID:[NSNumber numberWithInteger:[[[href componentsSeparatedByString:@"-"] objectAtIndex:1] integerValue]]];
            [topic setTitle:content];
            [topic setReplyCount:[NSNumber numberWithInteger:[replyCount integerValue]]];
            [topic setFID:[NSNumber numberWithInteger:[context[@"FID"] integerValue]]];
            [topics addObject:topic];
        }
    }

    return (NSArray *)topics;
}


+ (NSArray *) contentsFromHTMLData:(NSData *)rawData withOffset:(NSInteger)offset
{
    NSLog(@"Begin Parsing.");
    NSDate *start = [NSDate date];
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    NSArray *elements  = [xpathParser searchWithXPathQuery:@"//div[@id='postlist']/div"];

    NSMutableArray *floorList = [[NSMutableArray alloc] init];
    NSLog(@"Floor count: %lu",(unsigned long)[elements count]);
    
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
            
            //parse post time
            TFHppleElement *postTimeNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//div/em/span"] firstObject];
            if (postTimeNode) {
                [floor setPostTime: [postTimeNode objectForKey:@"title"]];
            } else {
                TFHppleElement *postTimeNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//div/em"] firstObject];
                [floor setPostTime: [postTimeNode text]];
            }
            
            //parse index mark
            TFHppleElement *floorIndexMarkNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']/div/strong/a"] firstObject];
            if ([[floorIndexMarkNode childrenWithTagName:@"em"] count] != 0) {
                [floor setIndexMark: [[floorIndexMarkNode firstChildWithTagName:@"em"] text]];
            } else {
                [floor setIndexMark: [[floorIndexMarkNode text] stringByReplacingOccurrencesOfString:@"\r\n" withString:@""]];
            }
            
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

    NSTimeInterval timeInterval = [start timeIntervalSinceNow];
    NSLog(@"Finish Parsing time elapsed:%f",-timeInterval);
    
    return floorList;
}

+ (NSString *)generateContentPage:(NSArray *)floorList
{
    NSString *finalString = [[NSString alloc] init];
    for (S1Floor *topicFloor in floorList) {

        //process indexmark
        NSString *floorIndexMark = topicFloor.indexMark;
        if ([floorList indexOfObject:topicFloor] != 0) {
            floorIndexMark = [@"#" stringByAppendingString:topicFloor.indexMark];
        }
        //process time
        NSString *floorPostTime = topicFloor.postTime;
        if ([floorPostTime hasPrefix:@"发表于 "]) {
            floorPostTime = [floorPostTime stringByReplacingOccurrencesOfString:@"发表于 " withString:@""];
        }
        floorPostTime = [[self translateDateTimeString:floorPostTime] stringByAppendingString:[@" | "  stringByAppendingString: floorPostTime]];
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
        
        NSString *floorTemplatePath = [[NSBundle mainBundle] pathForResource:@"FloorTemplate" ofType:@"html"];
        NSData *floorTemplateData = [NSData dataWithContentsOfFile:floorTemplatePath];
        NSString *floorTemplate = [[NSString alloc] initWithData:floorTemplateData  encoding:NSUTF8StringEncoding];
        NSString *replyLinkString = @"";
        if ([[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"]) {
            replyLinkString = [NSString stringWithFormat: @"<div class=\"reply\"><a href=\"/reply?%@\">回复</a></div>" ,topicFloor.indexMark];
        }
        NSString *output = [NSString stringWithFormat:floorTemplate, floorIndexMark, topicFloor.author, floorPostTime, replyLinkString, topicFloor.content, floorAttachment];
        if ([floorList indexOfObject:topicFloor] != 0) {
            output = [@"<br />" stringByAppendingString:output];
        }
        finalString = [finalString stringByAppendingString:output];
    }
    
    NSString *threadTemplatePath = [[NSBundle mainBundle] pathForResource:@"ThreadTemplate" ofType:@"html"];
    NSData *threadTemplateData = [NSData dataWithContentsOfFile:threadTemplatePath];
    NSString *threadTemplate = [[NSString alloc] initWithData:threadTemplateData  encoding:NSUTF8StringEncoding];
    
    NSString *cssPath = nil;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        NSString *fontSizeKey = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
        if ([fontSizeKey isEqualToString:@"15px"]) {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content" ofType:@"css"];
        } else {
            cssPath = [[NSBundle mainBundle] pathForResource:@"content_larger_font" ofType:@"css"];
        }
    } else {
        cssPath = [[NSBundle mainBundle] pathForResource:@"content_ipad" ofType:@"css"];
    }
    finalString = [S1Parser processImagesInHTMLString:[NSString stringWithFormat:@"<div>%@</div>", finalString]];
    NSString *threadPage = [NSString stringWithFormat:threadTemplate, cssPath, finalString];
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
+ (BOOL)checkLoginState:(NSString *)HTMLString
{
    NSString *pattern = @"mod=logging&amp;action=logout";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:HTMLString options:NSMatchingReportProgress range:NSMakeRange(0, HTMLString.length)];
    NSInteger num = [result numberOfRanges];
    if (num == 0) {
        return NO;
    }
    return YES;
}


@end
