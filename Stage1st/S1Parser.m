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

#define kNumberPerPage 50

@interface S1Parser()
+(NSString *)processImagesInHTMLString:(NSString *)HTMLString;
@end

@implementation S1Parser
+(NSString *)processImagesInHTMLString:(NSString *)HTMLString
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


+ (NSArray *)topicsFromHTMLData:(NSData *)rawData withContext:(NSDictionary *)context
{
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    NSArray *elements  = [xpathParser searchWithXPathQuery:@"//table[@id='threadlisttableid']//tbody"];
    NSMutableArray *topics = [NSMutableArray array];
    
    NSLog(@"Topic count: %d",[elements count]);
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


+ (NSString *) contentsFromHTMLData:(NSData *)rawData withOffset:(NSInteger)offset
{
    NSLog(@"Begin Parsing.");
    NSDate *start = [NSDate date];
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    NSArray *elements  = [xpathParser searchWithXPathQuery:@"//div[@id='postlist']/div"];
    NSString *finalString = [[NSString alloc] init];
    
    NSLog(@"Floor count: %d",[elements count]);
    if ([elements count]) {
        BOOL not_first_floor_flag = NO;
        for (TFHppleElement *element in elements){
            if (![[element objectForKey:@"id"] hasPrefix:@"post_"]) {
                continue;
            }
            TFHpple *xpathParserForRow = [[TFHpple alloc] initWithHTMLData:[element.raw dataUsingEncoding:NSUTF8StringEncoding]];
            TFHppleElement *authorNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='pls']//div[@class='authi']/a"] firstObject];
            NSString *author = [authorNode text];

            TFHppleElement *postTimeNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//div/em/span"] firstObject];
            NSString *postTime = nil;
            if (postTimeNode) {
                postTime = [postTimeNode objectForKey:@"title"];
            } else {
                TFHppleElement *postTimeNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//div/em"] firstObject];
                postTime = [postTimeNode text];
            }
            
            TFHppleElement *floorIndexMarkNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']/div/strong/a"] firstObject];
            NSString *floorIndexMark = nil;
            if ([[floorIndexMarkNode childrenWithTagName:@"em"] count] != 0) {
                floorIndexMark = [@"#" stringByAppendingString:[[floorIndexMarkNode firstChildWithTagName:@"em"] text]];
            } else {
                floorIndexMark = [floorIndexMarkNode text];
            }
            
            TFHppleElement *floorContentNode  = [[xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//td[@class='t_f']"] firstObject];
            NSString *floorContent = [floorContentNode raw];
            
            
            NSArray *floorAttachmentArray = [xpathParserForRow searchWithXPathQuery:@"//td[@class='plc']//div[@class='mbn savephotop']/img"];
            NSString *floorAttachment = @"";
            if ([floorAttachmentArray count]) {
                NSString *imageAttachmentsString = @"";
                for (TFHppleElement * floorAttachmentNode in floorAttachmentArray){
                    NSString *imageString = [floorAttachmentNode raw];
                    if ([floorAttachmentArray indexOfObject:floorAttachmentNode] != 0) {
                        imageString = [@"<br /><br />" stringByAppendingString:imageString];
                    }
                    imageAttachmentsString = [imageAttachmentsString stringByAppendingString:imageString];
                }
                floorAttachment = [NSString stringWithFormat:@"<tr class='attachment'><td>%@</td></tr>", imageAttachmentsString];
            }
            
            
            NSBundle *bundle = [NSBundle mainBundle];
            NSString *floorTemplatePath = [bundle pathForResource:@"FloorTemplate" ofType:@"html"];
            NSData *floorTemplateData = [NSData dataWithContentsOfFile:floorTemplatePath];
            NSString *floorTemplate = [[NSString alloc] initWithData:floorTemplateData  encoding:NSUTF8StringEncoding];
            NSString *output = [NSString stringWithFormat:floorTemplate, floorIndexMark, author, postTime, floorContent, floorAttachment];
            if (not_first_floor_flag) {
                output = [@"<br />" stringByAppendingString:output];
            } else {
                not_first_floor_flag = YES;
            }
            finalString = [finalString stringByAppendingString:output];
        }
    }

    NSBundle *bundle = [NSBundle mainBundle];
    NSString *threadTemplatePath = [bundle pathForResource:@"ThreadTemplate" ofType:@"html"];
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
    NSTimeInterval timeInterval = [start timeIntervalSinceNow];
    NSLog(@"Finish Parsing time elapsed:%f",-timeInterval);
    return threadPage;
}


+ (NSString *)formhashFromThreadString:(NSString *)HTMLString
{
    NSString *pattern = @"name=\"formhash\" value=\"([0-9a-zA-Z]+)\"";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:HTMLString options:NSMatchingReportProgress range:NSMakeRange(0, HTMLString.length)];
    NSString *formhash = [HTMLString substringWithRange:[result rangeAtIndex:1]];
    return formhash;
}

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
