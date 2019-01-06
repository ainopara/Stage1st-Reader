//
// REComposeViewController.m
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

#import "REComposeViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <Masonry/Masonry.h>
#import "Stage1st-Swift.h"

@interface REComposeViewController () <REComposeSheetViewDelegate> {
    UIView *_backgroundView;
    UIView *_backView;
    UIView *_containerView;
    CGFloat _keyboardHeight;
}

@property (assign, readwrite, nonatomic) BOOL userUpdatedAttachment;
@property (nonatomic, strong) REComposeSheetView *sheetView;

@end

@implementation REComposeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _cornerRadius = 6;
        _keyboardHeight = UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]) ?(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 387 : 197) : (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 299 : 252.0);
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor clearColor];

    _backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    _backgroundView.opaque = NO;
    _backgroundView.alpha = 0;
    _backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    
    [self.view addSubview:_backgroundView];
    [_backgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.frame), CGRectGetWidth(self.view.frame), 202)];
    _containerView.alpha = 0;

    [self.view addSubview:_containerView];
    
    _backView = [[UIView alloc] initWithFrame:CGRectZero];
    _backView.layer.cornerRadius = _cornerRadius;
    _backView.layer.rasterizationScale = [UIScreen mainScreen].scale;

    [_backView addSubview:self.sheetView];
    [self.sheetView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self->_backView);
    }];

    [_containerView addSubview:_backView];
    [_backView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self->_containerView);
    }];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateKeyboardFrame:) name:UIKeyboardDidShowNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.sheetView.textView becomeFirstResponder];
    [UIView animateWithDuration:0.3 animations:^{
        self->_containerView.alpha = 1;
        self->_backgroundView.alpha = 1;
    }];
}

- (void)layoutWithWidth:(NSInteger)width height:(NSInteger)height {
    DDLogDebug(@"layout:w%ld, h%ld",(long)width, (long)height);
    NSInteger offset = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 60 : 4;
    if (@available(iOS 11.0, *)) {
        offset += self.view.safeAreaInsets.left;
    }
    NSInteger expectComposeViewHeight = 202;
    NSInteger minimumComposeViewWidth = 320;
    
    // decide container's frame ( y position and height)
    CGRect frame = _containerView.frame;
    frame.size.height = expectComposeViewHeight;

    NSInteger yPosition = (height - _keyboardHeight - expectComposeViewHeight) / 2;
    if (yPosition < 20) {
        frame.size.height = height - _keyboardHeight - 20 - 4;
        frame.origin.y = 20;
    } else {
        frame.origin.y = yPosition;
    }

    if (width - offset * 2.0 < minimumComposeViewWidth) {
        offset = (width - minimumComposeViewWidth) / 2.0;
        if (@available(iOS 11.0, *)) {
            if (offset < 4.0 + self.view.safeAreaInsets.left) {
                offset = 4.0 + self.view.safeAreaInsets.left;
            }
        } else {
            if (offset < 4.0) {
                offset = 4.0;
            }
        }
    }
    frame.origin.x = offset;
    frame.size.width = width - offset * 2.0;
    _containerView.frame = frame;
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    if (self.presentedViewController != nil) {
        [super dismissViewControllerAnimated:flag completion:completion];
        return;
    }

    [self.sheetView.textView endEditing:YES];

    [UIView animateWithDuration:0.4 animations:^{
        self->_containerView.alpha = 0;
    }];
    
    [UIView animateWithDuration:0.4 delay:0.1 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self->_backgroundView.alpha = 0;
    } completion:^(BOOL finished) {
        if (completion) {
            completion();
        }
    }];

    [super dismissViewControllerAnimated:flag completion:completion];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self layoutWithWidth:CGRectGetWidth(self.view.frame) height:CGRectGetHeight(self.view.frame)];
    } completion:nil];
}

#pragma mark - Accessors

- (UINavigationItem *)navigationItem {
    return self.sheetView.navigationItem;
}

- (UINavigationBar *)navigationBar {
    return self.sheetView.navigationBar;
}

- (NSString *)plainText {
    return [self.sheetView.textView.attributedText s1_getPlainString];
}

- (void)setSheetBackgroundColor:(UIColor *)sheetBackgroundColor {
    self.sheetView.backgroundColor = sheetBackgroundColor;
}

- (UIColor *)sheetBackgroundColor {
    return self.sheetView.backgroundColor;
}

- (REComposeSheetView *)sheetView {
    if (_sheetView == nil) {
        _sheetView = [[REComposeSheetView alloc] initWithFrame:CGRectZero];
        _sheetView.layer.cornerRadius = _cornerRadius;
        _sheetView.clipsToBounds = YES;
        _sheetView.delegate = self;
    }
    return _sheetView;
}

#pragma mark - Input View and Accessory View

- (DEComposeTextView *)textView {
    return self.sheetView.textView;
}

- (void)setAccessoryView:(UIView *)view {
    self.sheetView.textView.inputAccessoryView = view;
}

- (UIView *)accessoryView {
    return self.sheetView.textView.inputAccessoryView;
}

- (void)setInputView:(UIView *)view {
    self.sheetView.textView.inputView = view;
}

- (UIView *)inputView {
    return self.sheetView.textView.inputView;
}

- (void)reloadInputViews {
    [super reloadInputViews];
    [self.sheetView.textView reloadInputViews];
}

#pragma mark - REComposeSheetViewDelegate

- (void)cancelButtonPressed {
    id<REComposeViewControllerDelegate> localDelegate = _delegate;
    if (localDelegate && [localDelegate respondsToSelector:@selector(composeViewController:didFinishWithResult:)]) {
        [localDelegate composeViewController:self didFinishWithResult:REComposeResultCancelled];
    }
}

- (void)postButtonPressed {
    id<REComposeViewControllerDelegate> localDelegate = _delegate;
    if (localDelegate && [localDelegate respondsToSelector:@selector(composeViewController:didFinishWithResult:)]) {
        [localDelegate composeViewController:self didFinishWithResult:REComposeResultPosted];
    }
}

#pragma mark - Notification

- (void)updateKeyboardFrame:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    CGFloat keyboardHeight = CGRectGetHeight([[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue]);
    NSTimeInterval timeInterval = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
//    UIViewAnimationCurve animationCurve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
    DDLogDebug(@"keyboard height: %f", keyboardHeight);
    if (_keyboardHeight != keyboardHeight) {
        _keyboardHeight = keyboardHeight;
        [UIView animateWithDuration:timeInterval delay:0.0 options:0 animations:^{
            [self layoutWithWidth:CGRectGetWidth(self.view.frame) height:CGRectGetHeight(self.view.frame)];
        } completion:NULL];
    }
}

@end
