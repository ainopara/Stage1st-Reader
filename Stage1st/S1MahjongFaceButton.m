//
//  S1MahjongFaceButton.m
//  Stage1st
//
//  Created by Zheng Li on 5/30/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1MahjongFaceButton.h"

@implementation S1MahjongFaceButton

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    DDLogVerbose(@"[MahjongFaceButton] %@, %@", self.mahjongFaceKey, event);
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(1.2, 1.2);
    }];
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    DDLogVerbose(@"[MahjongFaceButton] %@, %@", self.mahjongFaceKey, event);
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformIdentity;
    }];
    [super touchesEnded:touches withEvent:event];
}

@end
