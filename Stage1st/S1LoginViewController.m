//
//  S1LoginViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 3/5/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1LoginViewController.h"
#import "S1NetworkManager.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "OnePasswordExtension.h"

#define _DEFAULT_TEXT_FIELD_RECT (CGRect){{120.0f, 11.0f}, {170.0f, 21.0f}}

@interface S1LoginViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *usernameField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UIButton *onepasswordSigninButton;
@property (weak, nonatomic) IBOutlet UIButton *loginButton;

@end

@implementation S1LoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.usernameField setDelegate:self];
    self.usernameField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserIDCached"];
    [self.passwordField setDelegate:self];
    
    [self updateUI];
}


#pragma mark - UITextField Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    
    if ([textField.placeholder isEqualToString:NSLocalizedString(@"LoginView_Username", @"Username")]) {
        [self.passwordField becomeFirstResponder];
    } else if ([textField.placeholder isEqualToString:NSLocalizedString(@"LoginView_Password", @"Password")]) {
        [textField resignFirstResponder];
        [self login:nil];
    }
    return YES;
}

#pragma mark - Helper

- (void)clearCookiers
{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [cookieStorage cookies];
    [cookies enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSHTTPCookie *cookie = obj;
        [cookieStorage deleteCookie:cookie];
    }];
}

- (void)updateUI {
    NSString *inLoginStateID = [[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"];
    
    if (inLoginStateID) {
        [self.usernameField setEnabled:NO];
        [self.passwordField setHidden:YES];
        [self.loginButton setTitle:NSLocalizedString(@"SettingView_Logout", @"Logout") forState:UIControlStateNormal];
        [self.onepasswordSigninButton setHidden:YES];
    } else {
        [self.usernameField setEnabled:YES];
        [self.passwordField setHidden:NO];
        [self.loginButton setTitle:NSLocalizedString(@"SettingView_Login", @"Login") forState:UIControlStateNormal];
        [self.onepasswordSigninButton setHidden:![[OnePasswordExtension sharedExtension] isAppExtensionAvailable]];
    }
}

- (IBAction)findLoginFrom1Password:(UIButton *)sender {
    __weak __typeof__(self) weakSelf = self;
    [[OnePasswordExtension sharedExtension] findLoginForURLString:[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] forViewController:self sender:sender completion:^(NSDictionary *loginDict, NSError *error) {
        if (!loginDict) {
            if (error.code != AppExtensionErrorCodeCancelledByUser) {
                DDLogWarn(@"Error invoking 1Password App Extension for find login: %@", error);
            }
            return;
        }
        
        __strong __typeof__(self) strongSelf = weakSelf;
        strongSelf.usernameField.text = loginDict[AppExtensionUsernameKey];
        strongSelf.passwordField.text = loginDict[AppExtensionPasswordKey];
    }];
}

- (IBAction)login:(UIButton *)sender {
    NSString *inLoginStateID = [[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"];
    if (inLoginStateID) {
        //Logout
        [self clearCookiers];
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"InLoginStateID"];
        [self updateUI];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SettingView_Logout", @"") message:NSLocalizedString(@"LoginView_Logout_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"") otherButtonTitles:nil];
        [alertView show];
    } else {
        //Login
        if (self.usernameField.text.length > 0 && self.passwordField.text.length > 0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            [self.loginButton setEnabled:NO];
            __weak __typeof__(self) weakSelf = self;
            
            [S1NetworkManager postLoginForUsername:self.usernameField.text andPassword:self.passwordField.text success:^(NSURLSessionDataTask *task, id responseObject) {
                NSString *result = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                DDLogDebug(@"[LoginVC] Login response: %@", result);
                DDLogVerbose(@"%@", [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]);
                __strong __typeof__(self) strongMe = weakSelf;
                NSRange failureMsgRange = [result rangeOfString:@"window.location.href"];
                if (failureMsgRange.location != NSNotFound) {
                    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
                    [userDefault setValue:strongMe.usernameField.text forKey:@"InLoginStateID"];
                    [userDefault setValue:strongMe.usernameField.text forKey:@"UserIDCached"];
                    [strongMe updateUI];
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SettingView_Login", @"") message:NSLocalizedString(@"LoginView_Get_Login_Status_Success_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"") otherButtonTitles:nil];
                    [alertView show];
                } else {
                    [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"InLoginStateID"];
                    [[NSUserDefaults standardUserDefaults] setValue:strongMe.usernameField.text forKey:@"UserIDCached"];
                    [strongMe clearCookiers];
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SettingView_Login", @"") message:NSLocalizedString(@"LoginView_Get_Login_Status_Failure_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"") otherButtonTitles:nil];
                    [alertView show];
                }
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                [strongMe.loginButton setEnabled:YES];
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                DDLogError(@"[LoginVC] Login failure: %@", error);
                __strong __typeof__(self) strongMe = weakSelf;
                [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"InLoginStateID"];
                [[NSUserDefaults standardUserDefaults] setValue:strongMe.usernameField.text forKey:@"UserIDCached"];
                [strongMe clearCookiers];
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SettingView_Login", @"") message:NSLocalizedString(@"LoginView_Get_Login_Status_Failure_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"") otherButtonTitles:nil];
                [alertView show];
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                [strongMe.loginButton setEnabled:YES];
            }];
        }
    }
}

@end
