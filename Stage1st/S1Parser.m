//
//  S1Parser.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Parser.h"
#import "S1Topic.h"
#import "GTMNSString+HTML.h"
#import "TFHpple.h"
#import "DDXML.h"
#import "DDXMLElementAdditions.h"

#define kNumberPerPage 50

static NSString * const topicPattern = @"<li><a href=.*?tid-(\\d+).*?>(.*?)</a>.*?\\((\\d+)";
static NSString * const cssPattern = @"</style>";
static NSString * const cleanupPattern = @"(?:<br />(<br />)?\\r\\n<center>.*?</center>)|(?:<table cellspacing=\"1\" cellpadding=\"0\".*?</table>.*?</table>)|(?:src=\"http://[-.0-9a-zA-Z]+/2b/images/back\\.gif\")|(?:onload=\"if\\(this.offsetWidth>'600'\\)this.width='600';\")";
static NSString * const indexPattern = @"td><b>(.*?)</b></td>\\r\\n<td align=\"right\" class=\"smalltxt\"";


@implementation S1Parser

+ (NSArray *)topicsFromHTMLString:(NSString *)rawString withContext:(NSDictionary *)context
{
    NSString *HTMLString = [rawString gtm_stringByUnescapingFromHTML];
    NSRegularExpression *re = [[NSRegularExpression alloc]
                                    initWithPattern:topicPattern
                                    options:NSRegularExpressionDotMatchesLineSeparators
                                    error:nil];
    NSMutableArray *topics = [NSMutableArray array];
    
    [re enumerateMatchesInString:HTMLString
                         options:NSMatchingReportProgress
                           range:NSMakeRange(0, [HTMLString length])
                      usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                          if (result) {
                              S1Topic *topic = [[S1Topic alloc] init];
                              [topic setTopicID:[HTMLString substringWithRange:[result rangeAtIndex:1]]];
                              [topic setTitle:[HTMLString substringWithRange:[result rangeAtIndex:2]]];
                              [topic setReplyCount:[HTMLString substringWithRange:[result rangeAtIndex:3]]];
                              [topic setFID:context[@"FID"]];
                              [topics addObject:topic];
                          }
                      }];
    return (NSArray *)topics;
}

+ (NSArray *)topicsFromHTMLData:(NSData *)rawData withContext:(NSDictionary *)context
{
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    NSArray *elements  = [xpathParser searchWithXPathQuery:@"//table[@id='threadlisttableid']//tbody"];
    NSMutableArray *topics = [NSMutableArray array];
    
    NSLog(@"%d",[elements count]);
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
            [topic setTopicID:[[href componentsSeparatedByString:@"-"] objectAtIndex:1]];
            [topic setTitle:content];
            [topic setReplyCount:replyCount];
            [topic setFID:context[@"FID"]];
            [topics addObject:topic];
        }
    }

    return (NSArray *)topics;
}

+ (NSString *)contentsFromHTMLString:(NSMutableString *)HTMLString withOffset:(NSInteger)offset
{
    NSRegularExpression *re = nil;
    //Add index
    __block NSInteger index = kNumberPerPage * (offset - 1);
    re = [[NSRegularExpression alloc] initWithPattern:indexPattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re enumerateMatchesInString:HTMLString
                         options:NSMatchingReportProgress
                           range:NSMakeRange(0, [HTMLString length])
                      usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                          if (result) {
                              NSRange range = [result rangeAtIndex:1];
                              NSString *author = [HTMLString substringWithRange:range];
                              NSString *stringAddedIndex = [NSString stringWithFormat:@"#%d %@", index, author];
                              index += 1;
                              [HTMLString replaceCharactersInRange:range withString:stringAddedIndex];
                          }
                      }];
    
    //Clean Up
    re = [[NSRegularExpression alloc] initWithPattern:cleanupPattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re replaceMatchesInString:HTMLString options:NSMatchingReportProgress range:NSMakeRange(0, [HTMLString length]) withTemplate:@""];
    

    
    //Add Customized CSS
    NSRange rangeToReplace = [HTMLString rangeOfString:@"<!--css-->"];
    if (rangeToReplace.location != NSNotFound) {
        NSString *path = nil;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            NSString *fontSizeKey = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
            if ([fontSizeKey isEqualToString:@"15px"]) {
                path = [[NSBundle mainBundle] pathForResource:@"content" ofType:@"css"];
            } else {
                path = [[NSBundle mainBundle] pathForResource:@"content_larger_font" ofType:@"css"];
            }
        } else {
            path = [[NSBundle mainBundle] pathForResource:@"content_ipad" ofType:@"css"];
        }
        NSString *stringToReplace = [NSString stringWithFormat:@"<link rel=\"stylesheet\" href=\"file://%@\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">", path];
        [HTMLString replaceCharactersInRange:rangeToReplace withString:stringToReplace];
    }
    return (NSString *)HTMLString;
}

+ (NSString *) contentsFromHTMLData:(NSData *)rawData withOffset:(NSInteger)offset
{
    TFHpple *xpathParser = [[TFHpple alloc] initWithHTMLData:rawData];
    NSArray *elements  = [xpathParser searchWithXPathQuery:@"//div[@id='postlist']/div"];
    NSString *finalString = [[NSString alloc] init];
    
    NSLog(@"%d",[elements count]);
    if ([elements count]) {
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
            DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:[floorContent dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            NSArray *images = [xmlDoc nodesForXPath:@"//img" error:nil];
            for (DDXMLElement *image in images) {
                NSString *imageSrc = [[image attributeForName:@"src"] stringValue];
                NSLog(@"image Src:%@",imageSrc);
                NSString *imageFile = [[image attributeForName:@"file"] stringValue];
                NSLog(@"image File:%@",imageFile);
                if (imageFile) {
                    [image removeAttributeForName:@"src"];
                    [image addAttributeWithName:@"src" stringValue:imageFile];
                    [image removeAttributeForName:@"width"];
                    [image removeAttributeForName:@"height"];
                }
                else if (imageSrc && (![imageSrc hasPrefix:@"http"])) {
                    [image removeAttributeForName:@"src"];
                    [image addAttributeWithName:@"src" stringValue:[@"http://bbs.saraba1st.com/2b/" stringByAppendingString:imageSrc]];
                }

            }
            floorContent = [xmlDoc XMLStringWithOptions:DDXMLNodePrettyPrint];
            floorContent = [floorContent stringByReplacingOccurrencesOfString:@"<br></br>" withString:@"<br />"];
            NSBundle *bundle = [NSBundle mainBundle];
            NSString *floorTemplatePath = [bundle pathForResource:@"FloorTemplate" ofType:@"html"];
            NSData *floorTemplateData = [NSData dataWithContentsOfFile:floorTemplatePath];
            NSString *floorTemplate = [[NSString alloc] initWithData:floorTemplateData  encoding:NSUTF8StringEncoding];
            NSString *output = [NSString stringWithFormat:floorTemplate, floorIndexMark, author, postTime, floorContent];
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
    NSString *threadPage = [NSString stringWithFormat:threadTemplate, cssPath, finalString];
    return threadPage;
}

@end
