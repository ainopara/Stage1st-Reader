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

#define kNumberPerPage 50

static NSString * const topicPattern = @"<li><a href=.*?t(\\d+).*?>(.*?)</a>.*?\\((\\d+)";
static NSString * const cssPattern = @"</style>";
static NSString * const cleanupPattern = @"(<br />(<br />)?\\r\\n<center>.*?</center>)|(<table cellspacing=\"1\" cellpadding=\"0\".*?</table>.*?</table>)|(src=\"http://bbs\\.saraba1st\\.com/2b/images/back\\.gif\")";
static NSString * const indexPattern = @"td><b>(.*?)</b></td>\\r\\n<td align=\"right\" class=\"smalltxt\"";


@implementation S1Parser

+ (NSArray *)topicsFromHTMLString:(NSString *)rawString
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
                              [topics addObject:topic];
                          }
                      }];
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
        NSString *path = [[NSBundle mainBundle] pathForResource:@"content" ofType:@"css"];
        NSString *stringToReplace = [NSString stringWithFormat:@"<link rel=\"stylesheet\" href=\"file://%@\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">", path];
        [HTMLString replaceCharactersInRange:rangeToReplace withString:stringToReplace];
    }
    return (NSString *)HTMLString;
}


@end
