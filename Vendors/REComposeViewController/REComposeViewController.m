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
#import "NSAttributedString+MahjongFaceExtension.h"

@interface REComposeViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (strong, readonly, nonatomic) UIView *backgroundView;
@property (strong, readonly, nonatomic) UIView *containerView;
@property (strong, readonly, nonatomic) REComposeSheetView *sheetView;
@property (assign, readwrite, nonatomic) BOOL userUpdatedAttachment;

@end

@implementation REComposeViewController {
    CGFloat _keyboardHeight;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _cornerRadius = 6;
        _keyboardHeight = UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]) ?(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 387 : 197) : (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 299 : 252.0);
        _sheetView = [[REComposeSheetView alloc] initWithFrame:CGRectMake(0, 0, self.currentWidth - 8, 202)];
        self.tintColor = [UIColor colorWithRed:247/255.0 green:247/255.0 blue:247/255.0 alpha:1.0];
    }
    return self;
}

- (int)currentWidth
{
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        UIScreen *screen = [UIScreen mainScreen];
        return (!UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) ? screen.bounds.size.width : screen.bounds.size.height;
    } else {
        UIScreen *screen = [UIScreen mainScreen];
        return screen.bounds.size.width;
    }
    
}

- (void)loadView
{
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow.rootViewController) {
        self.view = [[UIView alloc] initWithFrame:keyWindow.rootViewController.view.bounds];
    } else {
        self.view = [[UIView alloc] initWithFrame:keyWindow.bounds];
    }
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _backgroundView.opaque = NO;
    _backgroundView.alpha = 0;
    _backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    
    [self.view addSubview:_backgroundView];
    
    _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 202)];
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _containerView.alpha = 0;
    
    NSInteger offset = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 60 : 4;
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
        offset *= 2;
    }
    _backView = [[UIView alloc] initWithFrame:CGRectMake(offset, 0, self.currentWidth - offset*2, 202)];
    _backView.layer.cornerRadius = _cornerRadius;
    _backView.layer.rasterizationScale = [UIScreen mainScreen].scale;
    
    _sheetView.frame = _backView.bounds;
    _sheetView.layer.cornerRadius = _cornerRadius;
    _sheetView.clipsToBounds = YES;
    _sheetView.delegate = self;
    _sheetView.backgroundColor = self.tintColor;
    
    
    [_containerView addSubview:_backView];
    [self.view addSubview:_containerView];
    [_backView addSubview:_sheetView];
    
    if (!_attachmentImage)
        _attachmentImage = [[UIImage alloc] init];
    
    _sheetView.attachmentImageView.image = _attachmentImage;
    [_sheetView.attachmentViewButton addTarget:self
                                        action:@selector(didTapAttachmentView:)
                              forControlEvents:UIControlEventTouchUpInside];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewOrientationDidChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateKeyboardFrame:) name:UIKeyboardDidShowNotification object:nil];
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    [super didMoveToParentViewController:parent];

    _backgroundView.frame = _rootViewController.view.bounds;
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.containerView.alpha = 1;
        self.backgroundView.alpha = 1;
        [self layoutWithOrientation:self.interfaceOrientation width:self.view.frame.size.width height:self.view.frame.size.height];
        [self.sheetView.textView becomeFirstResponder];
    } completion:nil];

}

- (void)presentFromRootViewController
{
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [self presentFromViewController:rootViewController];
}

- (void)presentFromViewController:(UIViewController *)controller
{
    _rootViewController = controller;
    [controller addChildViewController:self];
    [controller.view addSubview:self.view];
    [self didMoveToParentViewController:controller];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear: animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutWithOrientation:(UIInterfaceOrientation)interfaceOrientation width:(NSInteger)width height:(NSInteger)height
{
    NSInteger offset = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 60 : 4;
    NSInteger expectComposeViewHeight = 202;
    
    
    CGRect frame = _containerView.frame;
    frame.size.height = expectComposeViewHeight;
    
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            offset *= 2;
        }
        frame.origin.y = (height - _keyboardHeight - expectComposeViewHeight) / 2;
        if (frame.origin.y < 20) {
            frame.size.height = height - _keyboardHeight - 20;
            frame.origin.y = 20;
        }
        _containerView.frame = frame;
        
        _containerView.clipsToBounds = YES;
        _backView.frame = CGRectMake(offset, 0, width - offset*2, UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? expectComposeViewHeight : frame.size.height);
        _sheetView.frame = _backView.bounds;
        
        CGRect paperclipFrame = _paperclipView.frame;
        paperclipFrame.origin.x = width - 73 - offset;
        _paperclipView.frame = paperclipFrame;
    } else {

        frame.origin.y = (height - _keyboardHeight - expectComposeViewHeight) / 2;
        if (frame.origin.y < 20) {
            frame.size.height = height - _keyboardHeight - 20 - 4;
            frame.origin.y = 20;
        }
        _containerView.frame = frame;
        _backView.frame = CGRectMake(offset, 0, width - offset*2, frame.size.height);
        _sheetView.frame = _backView.bounds;
        
        
        CGRect paperclipFrame = _paperclipView.frame;
        paperclipFrame.origin.x = width - 73 - offset;
        _paperclipView.frame = paperclipFrame;
    }
    
    
    _paperclipView.hidden = !_hasAttachment;
    _sheetView.attachmentView.hidden = !_hasAttachment;
    
    [_sheetView.navigationBar sizeToFit];
    
    CGRect attachmentViewFrame = _sheetView.attachmentView.frame;
    attachmentViewFrame.origin.x = _sheetView.frame.size.width - 84;
    attachmentViewFrame.origin.y = _sheetView.navigationBar.frame.size.height + 10;
    _sheetView.attachmentView.frame = attachmentViewFrame;
    
    CGRect textViewFrame = _sheetView.textView.frame;
    textViewFrame.size.width = !_hasAttachment ? _sheetView.textViewContainer.frame.size.width : _sheetView.textViewContainer.frame.size.width - 84;
    textViewFrame.size.width -= 14;
    _sheetView.textView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, _hasAttachment ? -85 : 0);
    textViewFrame.size.height = _sheetView.frame.size.height - _sheetView.navigationBar.frame.size.height - 3;
    _sheetView.textView.frame = textViewFrame;
    
    CGRect textViewContainerFrame = _sheetView.textViewContainer.frame;
    textViewContainerFrame.origin.y = _sheetView.navigationBar.frame.size.height;
    textViewContainerFrame.size.height = _sheetView.frame.size.height - _sheetView.navigationBar.frame.size.height;
    _sheetView.textViewContainer.frame = textViewContainerFrame;
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    [_sheetView.textView resignFirstResponder];
    __typeof(&*self) __weak weakSelf = self;
    
    [UIView animateWithDuration:0.4 animations:^{
        if (YES) {
            self.containerView.alpha = 0;
        } else {
            CGRect frame = weakSelf.containerView.frame;
            frame.origin.y =  weakSelf.rootViewController.view.frame.size.height;
            weakSelf.containerView.frame = frame;
        }
    }];
    
    [UIView animateWithDuration:0.4
                          delay:0.1
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         weakSelf.backgroundView.alpha = 0;
                     } completion:^(BOOL finished) {
                         [weakSelf.view removeFromSuperview];
                         [weakSelf removeFromParentViewController];
                         if (completion)
                             completion();
                     }];
}

#pragma mark -
#pragma mark Accessors

- (UINavigationItem *)navigationItem
{
    return _sheetView.navigationItem;
}

- (UINavigationBar *)navigationBar
{
    return _sheetView.navigationBar;
}

- (void)setAttachmentImage:(UIImage *)attachmentImage
{
    _attachmentImage = attachmentImage;
    _sheetView.attachmentImageView.image = _attachmentImage;
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
    self.sheetView.backgroundColor = tintColor;
}

- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    _sheetView.textView.keyboardAppearance = appearance;
}

- (void)setSheetViewBackgroundColor:(UIColor *)color {
    _sheetView.backgroundColor = color;
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
#pragma mark -
#pragma mark REComposeSheetViewDelegate

- (void)cancelButtonPressed
{
    id<REComposeViewControllerDelegate> localDelegate = _delegate;
    if (localDelegate && [localDelegate respondsToSelector:@selector(composeViewController:didFinishWithResult:)]) {
        [localDelegate composeViewController:self didFinishWithResult:REComposeResultCancelled];
    }
    if (_completionHandler)
        _completionHandler(self, REComposeResultCancelled);
}

- (void)postButtonPressed
{
    id<REComposeViewControllerDelegate> localDelegate = _delegate;
    if (localDelegate && [localDelegate respondsToSelector:@selector(composeViewController:didFinishWithResult:)]) {
        [localDelegate composeViewController:self didFinishWithResult:REComposeResultPosted];
    }
    if (_completionHandler)
        _completionHandler(self, REComposeResultPosted);
}

#pragma mark -
#pragma mark UIImagePickerControllerDelegate

- (void)didTapAttachmentView:(id)sender
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    // If our device has a cmera, we want to take a picture, otherwise we just pick from the library
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    [picker setSourceType:UIImagePickerControllerSourceTypeCamera];
    } else {
    [picker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    }

    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self setAttachmentImage:[info objectForKey:UIImagePickerControllerOriginalImage]];
    self.userUpdatedAttachment = YES;
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self.sheetView.textView becomeFirstResponder];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self.sheetView.textView becomeFirstResponder];
}

#pragma mark -
#pragma mark Orientation

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    return YES;
}

- (void)viewOrientationDidChanged:(NSNotification *)notification
{
    [self layoutWithOrientation:self.interfaceOrientation width:self.view.frame.size.width height:self.view.frame.size.height];
}

- (void)updateKeyboardFrame:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    CGSize kbSize = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    NSLog(@"%f", kbSize.height);
    if (_keyboardHeight != kbSize.height) {
        _keyboardHeight = kbSize.height;
        [UIView animateWithDuration:0.4 animations:^{
            [self layoutWithOrientation:self.interfaceOrientation width:self.view.frame.size.width height:self.view.frame.size.height];
        }];
    }
    
    
}

@end
