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
    [self.onepasswordSigninButton setHidden:![[OnePasswordExtension sharedExtension] isAppExtensionAvailable]];
    
    [self.usernameField setDelegate:self];
    self.usernameField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserIDCached"];
    [self.passwordField setDelegate:self];
    /*
    self.navigationItem.title = NSLocalizedString(@"LoginView_Title", @"Login");
        
    self.usernameField = [[UITextField alloc] initWithFrame:_DEFAULT_TEXT_FIELD_RECT];
    self.usernameField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserIDCached"];
    self.usernameField.textColor = [S1GlobalVariables color4];
    self.usernameField.tag = 99;
    self.usernameField.placeholder = NSLocalizedString(@"LoginView_ID", @"Id");
    self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.usernameField.delegate = self;
    
    self.passwordField = [[UITextField alloc] initWithFrame:_DEFAULT_TEXT_FIELD_RECT];
    self.passwordField.text = @"";
    self.passwordField.textColor = [S1GlobalVariables color4];
    self.passwordField.tag = 100;
    self.passwordField.placeholder = NSLocalizedString(@"LoginView_Password", @"Password");
    self.passwordField.delegate = self;
    self.passwordField.secureTextEntry = YES;
    __weak typeof(self) myself = self;
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = NSLocalizedString(@"LoginView_User_ID", @"User ID");
                if (cell.contentView.subviews.count < 2) {
                    CGRect toFrame = _DEFAULT_TEXT_FIELD_RECT;
                    toFrame.size.width = cell.contentView.bounds.size.width - toFrame.origin.x - 30.0f;
                    myself.usernameField.frame = toFrame;
                    [cell.contentView addSubview:myself.usernameField];
                }
            }];
        }];
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = NSLocalizedString(@"LoginView_Password", @"Password");
                if (cell.contentView.subviews.count < 2) {
                    CGRect toFrame = _DEFAULT_TEXT_FIELD_RECT;
                    toFrame.size.width = cell.contentView.bounds.size.width - toFrame.origin.x - 30.0f;
                    myself.passwordField.frame = toFrame;
                    [cell.contentView addSubview:myself.passwordField];
                }
            }];
        }];
    }];
    
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"LoginView_Get_Login_Status", @"Get Login Status");
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell){
                [myself clearCookiers];
                if (myself.usernameField.text.length > 0 && myself.passwordField.text.length > 0) {
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                    [myself login];
                }
            }];
        }];
    }];
     */
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


- (IBAction)findLoginFrom1Password:(UIButton *)sender {
    __weak typeof (self) miniMe = self;
    [[OnePasswordExtension sharedExtension] findLoginForURLString:[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] forViewController:self sender:sender completion:^(NSDictionary *loginDict, NSError *error) {
        if (!loginDict) {
            if (error.code != AppExtensionErrorCodeCancelledByUser) {
                NSLog(@"Error invoking 1Password App Extension for find login: %@", error);
            }
            return;
        }
        
        __strong typeof(self) strongMe = miniMe;
        strongMe.usernameField.text = loginDict[AppExtensionUsernameKey];
        strongMe.passwordField.text = loginDict[AppExtensionPasswordKey];
    }];
}

- (IBAction)login:(UIButton *)sender {
    if (self.usernameField.text.length > 0 && self.passwordField.text.length > 0) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        [self.loginButton setEnabled:NO];
        __weak typeof (self) miniMe = self;
        
        [S1NetworkManager postLoginForUsername:self.usernameField.text andPassword:self.passwordField.text success:^(NSURLSessionDataTask *task, id responseObject) {
            NSString *result = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            NSLog(@"Login Response: %@", result);
            NSLog(@"%@", [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]);
            __strong typeof(self) strongMe = miniMe;
            NSRange failureMsgRange = [result rangeOfString:@"window.location.href"];
            if (failureMsgRange.location != NSNotFound) {
                NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
                [userDefault setValue:strongMe.usernameField.text forKey:@"InLoginStateID"];
                [userDefault setValue:strongMe.usernameField.text forKey:@"UserIDCached"];
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
            NSLog(@"%@", error);
            __strong typeof(self) strongMe = miniMe;
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

@end
