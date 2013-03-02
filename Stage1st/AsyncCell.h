//
//  AsyncCell.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/19/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AsyncCell : UITableViewCell

- (void)asyncDrawRect:(CGRect)rect andContext:(CGContextRef)context;

@end
