//
//  S1Parser.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Parser.h"
#import "S1Topic.h"

static NSString * const topicPattern = @"<li><a href=.*?t(\\d+).*?>(.*?)</a>.*?\\((\\d+)";
static NSString * const cssPattern = @"</style>";
static NSString * const cleanupPattern = @"(<br />(<br />)?\\r\\n<center>.*?</center>)|(<table.*?cellpadding=\"0\".*?</table>.*?</table>)|(src=\"http://bbs\\.saraba1st\\.com/2b/images/back\\.gif\")";


@implementation S1Parser

+ (NSArray *)topicsFromHTMLString:(NSString *)HTMLString
{
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
                              [topics addObject:topic];
                          }
                      }];
    return (NSArray *)topics;
}

+ (NSString *)contentsFromHTMLString:(NSMutableString *)HTMLString
{
    //Clean Up
    NSRegularExpression *re = nil;
    re = [[NSRegularExpression alloc] initWithPattern:cleanupPattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    [re replaceMatchesInString:HTMLString options:NSMatchingReportProgress range:NSMakeRange(0, [HTMLString length]) withTemplate:@""];
    
    //Add Customized CSS
    NSRange rangeToReplace = [HTMLString rangeOfString:@"<!--css-->"];
    if (rangeToReplace.location != NSNotFound) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"content" ofType:@"css"];
        NSString *stringToReplace = [NSString stringWithFormat:@"<link rel=\"stylesheet\" href=\"file://%@\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">", path];
        [HTMLString replaceCharactersInRange:rangeToReplace withString:stringToReplace];
    }
    return (NSString *)HTMLString;
}


@end
