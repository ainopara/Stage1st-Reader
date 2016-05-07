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
#import "NSAttributedString+MahjongFaceExtension.h"

@interface REComposeViewController () <REComposeSheetViewDelegate> {
    REComposeSheetView *_sheetView;
    UIView *_backgroundView;
    UIView *_backView;
    UIView *_containerView;
    CGFloat _keyboardHeight;
}

@property (assign, readwrite, nonatomic) BOOL userUpdatedAttachment;

@end

@implementation REComposeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _cornerRadius = 6;
        _keyboardHeight = UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]) ?(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 387 : 197) : (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 299 : 252.0);
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad
{
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

    _sheetView = [[REComposeSheetView alloc] initWithFrame:CGRectZero];
    _sheetView.layer.cornerRadius = _cornerRadius;
    _sheetView.clipsToBounds = YES;
    _sheetView.delegate = self;
    _sheetView.backgroundColor = self.tintColor;

    [_backView addSubview:_sheetView];
    [_sheetView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_backView);
    }];

    [_containerView addSubview:_backView];
    [_backView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_containerView);
    }];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateKeyboardFrame:) name:UIKeyboardDidShowNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [_sheetView.textView becomeFirstResponder];
    [UIView animateWithDuration:0.3 animations:^{
        _containerView.alpha = 1;
        _backgroundView.alpha = 1;
    }];
}

- (void)layoutWithWidth:(NSInteger)width height:(NSInteger)height
{
    DDLogInfo(@"layout:w%ld, h%ld",(long)width, (long)height);
    NSInteger offset = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 60 : 4;
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
        if (offset < 4.0) {
            offset = 4.0;
        }
    }
    frame.origin.x = offset;
    frame.size.width = width - offset * 2.0;
    _containerView.frame = frame;
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    [_sheetView.textView endEditing:YES];

    [UIView animateWithDuration:0.4 animations:^{
        _containerView.alpha = 0;
    }];
    
    [UIView animateWithDuration:0.4 delay:0.1 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        _backgroundView.alpha = 0;
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

- (UINavigationItem *)navigationItem
{
    return _sheetView.navigationItem;
}

- (UINavigationBar *)navigationBar
{
    return _sheetView.navigationBar;
}

- (NSString *)text
{
    return [_sheetView.textView.attributedText getPlainString];
}

- (void)setText:(NSString *)text
{
    _sheetView.textView.text = text;
}

- (NSAttributedString *)attributedText
{
    return _sheetView.textView.attributedText;
}

- (void)setAttributedText:(NSAttributedString *)text
{
    _sheetView.textView.attributedText = text;
}


- (NSString *)placeholderText
{
    return _sheetView.textView.placeholder;
}

- (void)setPlaceholderText:(NSString *)placeholderText
{
    _sheetView.textView.placeholder = placeholderText;
}

- (void)setTintColor:(UIColor *)tintColor
{
    _tintColor = tintColor;
    _sheetView.backgroundColor = tintColor;
}

- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    _sheetView.textView.keyboardAppearance = appearance;
}

- (void)setTextViewTintColor:(UIColor *)color {
    _sheetView.textView.tintColor = color;
}

#pragma mark - Input View and Accessory View

- (DEComposeTextView *)textView {
    return _sheetView.textView;
}

- (void)setAccessoryView:(UIView *)view {
    _sheetView.textView.inputAccessoryView = view;
}

- (UIView *)accessoryView {
    return _sheetView.textView.inputAccessoryView;
}

- (void)setInputView:(UIView *)view {
    _sheetView.textView.inputView = view;
}

- (UIView *)inputView {
    return _sheetView.textView.inputView;
}

- (void)reloadInputViews {
    [super reloadInputViews];
    [_sheetView.textView reloadInputViews];
}

#pragma mark - REComposeSheetViewDelegate

- (void)cancelButtonPressed
{
    id<REComposeViewControllerDelegate> localDelegate = _delegate;
    if (localDelegate && [localDelegate respondsToSelector:@selector(composeViewController:didFinishWithResult:)]) {
        [localDelegate composeViewController:self didFinishWithResult:REComposeResultCancelled];
    }
}

- (void)postButtonPressed
{
    id<REComposeViewControllerDelegate> localDelegate = _delegate;
    if (localDelegate && [localDelegate respondsToSelector:@selector(composeViewController:didFinishWithResult:)]) {
        [localDelegate composeViewController:self didFinishWithResult:REComposeResultPosted];
    }
}

#pragma mark - Notification

- (void)updateKeyboardFrame:(NSNotification *)notification
{
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
