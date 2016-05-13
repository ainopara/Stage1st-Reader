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
#import <OnePasswordExtension/OnePasswordExtension.h>
#import <ActionSheetPicker_3_0/ActionSheetStringPicker.h>
#import <Masonry/Masonry.h>

@interface S1LoginViewController () <UITextFieldDelegate>

@end

@implementation S1LoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.usernameField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.usernameField.delegate = self;
    self.usernameField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserIDCached"];
    self.usernameField.borderStyle = UITextBorderStyleLine;
    [self.view addSubview:self.usernameField];

    [self.usernameField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@300.0);
        make.top.equalTo(self.mas_topLayoutGuideBottom).offset(64.0);
        make.centerX.equalTo(self.view);
    }];

    self.passwordField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.passwordField.delegate = self;
    self.passwordField.borderStyle = UITextBorderStyleLine;
    [self.view addSubview:self.passwordField];

    [self.passwordField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.centerX.equalTo(self.usernameField);
        make.top.equalTo(self.usernameField.mas_bottom).offset(12.0);
    }];

    self.onepasswordSigninButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.onepasswordSigninButton setImage:[UIImage imageNamed:@"OnePasswordButton"] forState:UIControlStateNormal];
    [self.onepasswordSigninButton addTarget:self action:@selector(findLoginFrom1Password:) forControlEvents:UIControlEventTouchUpInside];
    self.onepasswordSigninButton.tintColor = [[APColorManager sharedInstance] colorForKey:@"default.text.tint"];

    UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectZero];
    [buttonContainer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@24.0);
        make.width.equalTo(@28.0);
    }];
    [buttonContainer addSubview:self.onepasswordSigninButton];
    [self.onepasswordSigninButton mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.height.width.equalTo(@24.0);
        make.top.leading.bottom.equalTo(buttonContainer);
        make.trailing.equalTo(buttonContainer).offset(-4.0);
    }];
    self.passwordField.rightView = buttonContainer;
    self.passwordField.rightViewMode = UITextFieldViewModeAlways;

    self.questionSelectButton = [[UIButton alloc] initWithFrame:CGRectZero];
    [self.questionSelectButton setTitle:@"提示问题" forState:UIControlStateNormal];
    [self.questionSelectButton addTarget:self action:@selector(selectSecureQuestion:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.questionSelectButton];
    [self.questionSelectButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.centerX.equalTo(self.usernameField);
        make.top.equalTo(self.passwordField.mas_bottom).offset(12.0);
    }];

    self.answerField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.answerField.borderStyle = UITextBorderStyleLine;
    [self.view addSubview:self.answerField];
    [self.answerField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.centerX.equalTo(self.questionSelectButton);
        make.top.equalTo(self.questionSelectButton.mas_bottom).offset(12.0);
    }];

    self.loginButton = [[UIButton alloc] initWithFrame:CGRectZero];
    [self.loginButton setTitle:@"Login" forState:UIControlStateNormal];
    [self.loginButton addTarget:self action:@selector(login:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.loginButton];

    [self.loginButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.answerField.mas_bottom).offset(12.0);
        make.centerX.equalTo(self.answerField);
    }];

    [self updateUI];
}

- (void)updateUI {
    NSString *inLoginStateID = [[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"];

    if (inLoginStateID) {
        [self.usernameField setEnabled:NO];
        [self.passwordField setHidden:YES];
        [self.loginButton setTitle:NSLocalizedString(@"SettingView_Logout", @"Logout") forState:UIControlStateNormal];
    } else {
        [self.usernameField setEnabled:YES];
        [self.passwordField setHidden:NO];
        [self.loginButton setTitle:NSLocalizedString(@"SettingView_Login", @"Login") forState:UIControlStateNormal];
        self.passwordField.rightViewMode = [[OnePasswordExtension sharedExtension] isAppExtensionAvailable] ? UITextFieldViewModeAlways : UITextFieldViewModeNever;
    }
}

#pragma mark - UITextField Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([textField.placeholder isEqualToString:NSLocalizedString(@"LoginView_Username", @"Username")]) {
        [self.passwordField becomeFirstResponder];
    } else if ([textField.placeholder isEqualToString:NSLocalizedString(@"LoginView_Password", @"Password")]) {
        [textField resignFirstResponder];
        [self login:nil];
    }
    return YES;
}

#pragma mark - Action

- (void)clearCookies {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [cookieStorage cookies];
    [cookies enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSHTTPCookie *cookie = obj;
        [cookieStorage deleteCookie:cookie];
    }];
}

- (void)findLoginFrom1Password:(UIButton *)sender {
    __weak __typeof__(self) weakSelf = self;
    [[OnePasswordExtension sharedExtension] findLoginForURLString:[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] forViewController:self sender:sender completion:^(NSDictionary *loginDict, NSError *error) {
        if (!loginDict) {
            if (error.code != AppExtensionErrorCodeCancelledByUser) {
                DDLogInfo(@"Error invoking 1Password App Extension for find login: %@", error);
            }
            return;
        }
        
        __strong __typeof__(self) strongSelf = weakSelf;
        strongSelf.usernameField.text = loginDict[AppExtensionUsernameKey];
        strongSelf.passwordField.text = loginDict[AppExtensionPasswordKey];
    }];
}

- (void)selectSecureQuestion:(UIButton *)sender {
    DDLogDebug(@"debug secure question");
    NSArray *choices = @[@"安全提问（未设置请忽略）",
                         @"母亲的名字",
                         @"爷爷的名字",
                         @"父亲出生的城市",
                         @"您其中一位老师的名字",
                         @"您个人计算机的型号",
                         @"您最喜欢的餐馆名称",
                         @"驾驶执照最后四位数字"];
    ActionSheetStringPicker *picker = [[ActionSheetStringPicker alloc] initWithTitle:@"安全提问" rows:choices initialSelection:0 doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
        [sender setTitle:selectedValue forState:UIControlStateNormal];
    } cancelBlock:nil origin:sender];
    [picker showActionSheetPicker];
}

- (void)login:(UIButton *)sender {
    NSString *inLoginStateID = [[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"];
    if (inLoginStateID) {
        //Logout
        [[LoginManager sharedInstance] logout];
        [self updateUI];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"SettingView_Logout", @"") message:NSLocalizedString(@"LoginView_Logout_Message", @"") preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Message_OK", @"") style:UIAlertActionStyleCancel handler:NULL]];
        [self presentViewController:alertController animated:YES completion:NULL];
    } else {
        //Login
        [self tryLogin];
        return;
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
                    [strongMe clearCookies];
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
                [strongMe clearCookies];
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SettingView_Login", @"") message:NSLocalizedString(@"LoginView_Get_Login_Status_Failure_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"") otherButtonTitles:nil];
                [alertView show];
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                [strongMe.loginButton setEnabled:YES];
            }];
        }
    }
}

@end
