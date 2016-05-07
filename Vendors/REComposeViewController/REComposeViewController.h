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

@class REComposeViewController;

typedef NS_ENUM(NSUInteger, REComposeResult) {
    REComposeResultCancelled,
    REComposeResultPosted
};

typedef void (^REComposeViewControllerCompletionHandler)(REComposeViewController *composeViewController, REComposeResult result);

@protocol REComposeViewControllerDelegate;

@interface REComposeViewController : UIViewController

@property (copy, nonatomic) REComposeViewControllerCompletionHandler completionHandler;
@property (weak, nonatomic) id<REComposeViewControllerDelegate> delegate;
@property (assign, nonatomic) NSInteger cornerRadius;
@property (strong, nonatomic) NSString *text;
@property (strong, nonatomic) NSAttributedString *attributedText;
@property (strong, nonatomic) NSString *placeholderText;
@property (strong, readonly, nonatomic) DEComposeTextView *textView;
@property (strong, readonly, nonatomic) UINavigationBar *navigationBar;
@property (strong, readonly, nonatomic) UINavigationItem *navigationItem;
@property (strong, nonatomic) UIColor *tintColor;
@property (strong, nonatomic) UIView *accessoryView;
@property (strong, nonatomic) UIView *inputView;

- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance;
- (void)setTextViewTintColor:(UIColor *)color;

@end

@protocol REComposeViewControllerDelegate <NSObject>

- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result;

@end
