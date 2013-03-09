//
//  S1Parser.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S1Parser : NSObject

+ (NSArray *)topicsFromHTMLString:(NSString *)HTMLString;

+ (NSString *)contentsFromHTMLString:(NSMutableString *)HTMLString withOffset:(NSInteger)offset;

@end
