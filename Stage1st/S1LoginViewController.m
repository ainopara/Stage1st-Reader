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
    self.navigationItem.title = NSLocalizedString(@"登录设置", @"Login");
        
    self.userIDField = [[UITextField alloc] initWithFrame:_DEFAULT_TEXT_FIELD_RECT];
    self.userIDField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserID"];
    self.userIDField.textColor = [UIColor colorWithRed:56.0f/255.0f green:84.0f/255.0f blue:135.0f/255.0f alpha:1.0f];
    self.userIDField.tag = 99;
    self.userIDField.placeholder = NSLocalizedString(@"用户名", @"User Id");
    self.userIDField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.userIDField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.userIDField.delegate = self;
    
    self.userPasswordField = [[UITextField alloc] initWithFrame:_DEFAULT_TEXT_FIELD_RECT];
    self.userPasswordField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserPassword"];
    self.userPasswordField.textColor = [UIColor colorWithRed:56.0f/255.0f green:84.0f/255.0f blue:135.0f/255.0f alpha:1.0f];
    self.userPasswordField.tag = 100;
    self.userPasswordField.placeholder = NSLocalizedString(@"密码", @"Password");
    self.userPasswordField.delegate = self;
    self.userPasswordField.secureTextEntry = YES;
    __weak typeof(self) myself = self;
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = NSLocalizedString(@"用户名", @"ID");
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
                cell.textLabel.text = NSLocalizedString(@"密码", @"Password");
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
                cell.textLabel.text = NSLocalizedString(@"获取登录状态", @"Get Login Status");
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

- (void)viewWillDisappear:(BOOL)animated
{
    
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

- (void)login
{
    NSDictionary *param = @{
                            @"lgt" : @"0",
                            @"m" : @"bbs",
                            @"step" : @"2",
                            @"pwuser" : self.userIDField.text,
                            @"pwpwd" : self.userPasswordField.text,
                            @"jumpurl" : @"",
                            @"forward" : @"",
                            @"cktime" : @"31536000"                            
                            };
    
    [[self HTTPClient] postPath:@"login.php?"
                     parameters:param
                        success:^(AFHTTPRequestOperation *operation, id responseObject) {
                            NSString *result = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                            NSLog(@"Login Response: %@", result);
                            NSLog(@"%@", [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]);
                            
                            NSRange successMsgRange = [result rangeOfString:@"顺利登录"];
                            if (successMsgRange.location != NSNotFound) {
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
