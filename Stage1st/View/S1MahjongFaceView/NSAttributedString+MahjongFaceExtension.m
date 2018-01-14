//
//  NSAttributedString+MahjongFaceExtension.h
//  Stage1st
//
//  Created by Zheng Li on 5/19/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NSAttributedString+MahjongFaceExtension.h"
#import "S1MahjongFaceTextAttachment.h"

@implementation NSAttributedString (MahjongFaceExtension)

- (NSString *)getPlainString {
    NSMutableString *plainString = [NSMutableString stringWithString:self.string];
    __block NSUInteger base = 0;
    
    [self enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, self.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value && [value isKindOfClass:[S1MahjongFaceTextAttachment class]]) {
            [plainString replaceCharactersInRange:NSMakeRange(range.location + base, range.length)
                                       withString:((S1MahjongFaceTextAttachment *) value).mahjongFaceTag];
            base += ((S1MahjongFaceTextAttachment *) value).mahjongFaceTag.length - 1;
        }
    }];
    
    return plainString;
}

@end
