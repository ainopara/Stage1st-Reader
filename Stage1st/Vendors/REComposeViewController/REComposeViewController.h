//
// REComposeViewController.h
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

#import <UIKit/UIKit.h>
#import "REComposeSheetView.h"

@protocol REComposeViewControllerDelegate;

typedef NS_ENUM(NSUInteger, REComposeResult) {
    REComposeResultCancelled,
    REComposeResultPosted
};

@interface REComposeViewController : UIViewController

@property (weak, nonatomic) id <REComposeViewControllerDelegate> delegate;
@property (assign, nonatomic) NSInteger cornerRadius;
@property (nonatomic, strong, readonly) NSString *plainText;
@property (nonatomic, strong, readonly) DEComposeTextView *textView;
@property (nonatomic, strong, readonly) UINavigationBar *navigationBar;
@property (nonatomic, strong, readonly) UINavigationItem *navigationItem;
@property (nonatomic, strong) UIColor *sheetBackgroundColor;
@property (nonatomic, strong) UIView *accessoryView;
@property (nonatomic, strong) UIView *inputView;

@end

@protocol REComposeViewControllerDelegate <NSObject>

- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result;

@end
