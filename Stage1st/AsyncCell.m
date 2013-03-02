//
//  AsyncCell.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "AsyncCell.h"

@implementation AsyncCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self setNeedsDisplay];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self setNeedsDisplay];
}

- (void)asyncDrawRect:(CGRect)rect
{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef context = CGBitmapContextCreate(NULL, scale*rect.size.width, scale*rect.size.height, 8, scale*4*rect.size.width, colorSpace, kCGImageAlphaPremultipliedLast);
        
//        CGContextSetTextMatrix(context, CGAffineTransformIdentity);
        CGContextTranslateCTM(context, 0, scale * rect.size.height);
        CGContextScaleCTM(context, scale, -scale);
        
        [self asyncDrawRect:rect andContext:context];
        
        CGImageRef image = CGBitmapContextCreateImage(context);

        dispatch_async(dispatch_get_main_queue(), ^{
            self.contentView.layer.contents = (__bridge id)image;
            CGImageRelease(image);
        });
        
        CGColorSpaceRelease(colorSpace);
        CGContextRelease(context);
    });
}

- (void)asyncDrawRect:(CGRect)rect andContext:(CGContextRef)context
{
    return;
}


- (void)drawRect:(CGRect)rect
{
    [self asyncDrawRect:rect];
}


@end
