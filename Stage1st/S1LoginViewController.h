//
//  S1LoginViewController.h
//  Stage1st
//
//  Created by Suen Gabriel on 3/5/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//


@interface S1LoginViewController : UIViewController

@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UIButton *loginButton;

@property (nonatomic, strong) UIButton *onepasswordSigninButton;

@property (nonatomic, strong) UIButton *questionSelectButton;
@property (nonatomic, strong) UITextField *answerField;

@property (nonatomic, strong) UIImageView *seccodeImageView;
@property (nonatomic, strong) UITextField *seccodeField;

- (void)updateUI;

@end
