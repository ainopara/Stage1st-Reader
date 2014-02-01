//
//  S1LoginViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 3/5/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1LoginViewController.h"
#import "S1HTTPClient.h"
#import "AFNetworkActivityIndicatorManager.h"

#define _DEFAULT_TEXT_FIELD_RECT (CGRect){{120.0f, 11.0f}, {170.0f, 21.0f}}

@interface S1LoginViewController () <UITextFieldDelegate>

@property (nonatomic, strong) S1HTTPClient *HTTPClient;

@property (nonatomic, strong) UITextField *userIDField;
@property (nonatomic, strong) UITextField *userPasswordField;

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
    self.navigationItem.title = NSLocalizedString(@"LoginView_Title", @"Login");
        
    self.userIDField = [[UITextField alloc] initWithFrame:_DEFAULT_TEXT_FIELD_RECT];
    self.userIDField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserID"];
    self.userIDField.textColor = [S1GlobalVariables color4];
    self.userIDField.tag = 99;
    self.userIDField.placeholder = NSLocalizedString(@"LoginView_ID", @"Id");
    self.userIDField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.userIDField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.userIDField.delegate = self;
    
    self.userPasswordField = [[UITextField alloc] initWithFrame:_DEFAULT_TEXT_FIELD_RECT];
    self.userPasswordField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserPassword"];
    self.userPasswordField.textColor = [S1GlobalVariables color4];
    self.userPasswordField.tag = 100;
    self.userPasswordField.placeholder = NSLocalizedString(@"LoginView_Password", @"Password");
    self.userPasswordField.delegate = self;
    self.userPasswordField.secureTextEntry = YES;
    __weak typeof(self) myself = self;
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = NSLocalizedString(@"LoginView_User_ID", @"User ID");
                if (cell.contentView.subviews.count < 2) {
                    CGRect toFrame = _DEFAULT_TEXT_FIELD_RECT;
                    toFrame.size.width = cell.contentView.bounds.size.width - toFrame.origin.x - 30.0f;
                    myself.userIDField.frame = toFrame;
                    [cell.contentView addSubview:myself.userIDField];
                }
            }];
        }];
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = NSLocalizedString(@"LoginView_Password", @"Password");
                if (cell.contentView.subviews.count < 2) {
                    CGRect toFrame = _DEFAULT_TEXT_FIELD_RECT;
                    toFrame.size.width = cell.contentView.bounds.size.width - toFrame.origin.x - 30.0f;
                    myself.userPasswordField.frame = toFrame;
                    [cell.contentView addSubview:myself.userPasswordField];
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
                if (myself.userIDField.text.length > 0 && myself.userPasswordField.text.length > 0) {
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                    [myself login];
                }
            }];
        }];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (S1HTTPClient *)HTTPClient
{
    if (_HTTPClient) return _HTTPClient;
    NSString *baseURLString = [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"];
    _HTTPClient = [[S1HTTPClient alloc] initWithBaseURL:[NSURL URLWithString:[baseURLString stringByAppendingString:@"/2b/"]]];
    return _HTTPClient;
}

//Login from the standard web
- (void)login
{
    NSDictionary *param = @{
                            @"fastloginfield" : @"username",
                            @"username" : self.userIDField.text,
                            @"password" : self.userPasswordField.text,
                            @"handlekey" : @"ls",
                            @"quickforward" : @"yes",
                            @"cookietime" : @"2592000"
                            };
    
    [[self HTTPClient] postPath:@"member.php?mod=logging&action=login&loginsubmit=yes&infloat=yes&lssubmit=yes&inajax=1"
                     parameters:param
                        success:^(AFHTTPRequestOperation *operation, id responseObject) {
                            NSString *result = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                            NSLog(@"Login Response: %@", result);
                            NSLog(@"%@", [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]);
                            
                            NSRange successMsgRange = [result rangeOfString:@"window.location.href"];
                            if (successMsgRange.location != NSNotFound) {
                                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SettingView_Login", @"") message:NSLocalizedString(@"LoginView_Get_Login_Status_Success_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"") otherButtonTitles:nil];
                                [alertView show];
                                NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
                                [userDefault setValue:self.userIDField.text forKey:@"UserID"];
                                [userDefault setValue:self.userPasswordField.text forKey:@"UserPassword"];
                                
                            } else {
                                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SettingView_Login", @"") message:NSLocalizedString(@"LoginView_Get_Login_Status_Failure_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"") otherButtonTitles:nil];
                                [alertView show];
                            }
                            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                        }
                        failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                            NSLog(@"%@", error);
                            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SettingView_Login", @"") message:NSLocalizedString(@"LoginView_Get_Login_Status_Failure_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"") otherButtonTitles:nil];
                            [alertView show];
                            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                        }];
}

// Login from the mobile web
- (void)alternativelogin
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[self HTTPClient] postPath:@"m/login.php"
                     parameters:@{ @"pwuser":self.userIDField.text, @"pwpwd":self.userPasswordField.text, @"lgt":@"0" }
                        success:^(AFHTTPRequestOperation *operation, id responseObject) {
                            NSString *result = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                            NSLog(@"%@", result);
                            NSLog(@"%@", [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]);
                            if (result) {
                                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"登录" message:@"获取登录状态成功" delegate:nil cancelButtonTitle:@"完成" otherButtonTitles:nil];
                                [alertView show];
                                NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
                                [userDefault setValue:self.userIDField.text forKey:@"UserID"];
                                [userDefault setValue:self.userPasswordField.text forKey:@"UserPassword"];
                            } else {
                                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"登录" message:@"获取登录状态未成功" delegate:nil cancelButtonTitle:@"完成" otherButtonTitles:nil];
                                [alertView show];
                            }
                            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                        }
                        failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                            NSLog(@"%@", error);
                            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"登录" message:@"获取登录状态未成功" delegate:nil cancelButtonTitle:@"完成" otherButtonTitles:nil];
                            [alertView show];
                            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                        }];
}

#pragma mark - UITextField Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
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

@end
