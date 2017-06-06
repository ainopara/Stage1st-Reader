//
// REComposeSheetView.m
// REComposeViewController
//
// Copyright (c) 2013 Roman Efimov (https://github.com/romaonthego)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "REComposeSheetView.h"
#import "REComposeViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <Masonry/Masonry.h>

@implementation REComposeSheetView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        
        _navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 44)];
        [self addSubview:_navigationBar];
        [_navigationBar mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@44.0);
            make.top.leading.trailing.equalTo(self);
        }];

        _navigationItem = [[UINavigationItem alloc] initWithTitle:@""];
        _navigationBar.items = @[_navigationItem];
        
        UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"REComposeSheetView.Cancel", nil, [NSBundle mainBundle], @"Cancel", @"Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed)];
        
        UIBarButtonItem *postButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"REComposeSheetView.Post", nil, [NSBundle mainBundle], @"Post", @"Post") style:UIBarButtonItemStyleDone target:self action:@selector(postButtonPressed)];

        UIBarButtonItem *leftSeperator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        leftSeperator.width = 5.0;
        UIBarButtonItem *rightSeperator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        rightSeperator.width = 5.0;
        _navigationItem.leftBarButtonItems = @[leftSeperator, cancelButtonItem];
        _navigationItem.rightBarButtonItems = @[rightSeperator, postButtonItem];

        _textView = [[DEComposeTextView alloc] initWithFrame:CGRectZero];
        _textView.backgroundColor = [UIColor clearColor];
        _textView.font = [UIFont systemFontOfSize: 17];
        _textView.bounces = YES;

        [self insertSubview:_textView belowSubview:_navigationBar];
        [_textView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (_delegate) {
        _navigationItem.title = _delegate.title;
    }
    _textView.contentInset = UIEdgeInsetsMake(CGRectGetHeight(_navigationBar.frame), 0.0, 0.0, 0.0);
    _textView.scrollIndicatorInsets = _textView.contentInset;
}

- (void)cancelButtonPressed
{
    id <REComposeSheetViewDelegate> localDelegate = _delegate;
    if ([localDelegate respondsToSelector:@selector(cancelButtonPressed)])
        [localDelegate cancelButtonPressed];
}

- (void)postButtonPressed
{
    id <REComposeSheetViewDelegate> localDelegate = _delegate;
    if ([localDelegate respondsToSelector:@selector(postButtonPressed)])
        [localDelegate postButtonPressed];
}
@end
