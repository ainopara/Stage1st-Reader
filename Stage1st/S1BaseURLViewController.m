//
//  S1BaseURLViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 3/17/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1BaseURLViewController.h"

#define _DEFAULT_TEXT_FIELD_RECT (CGRect){{120.0f, 11.0f}, {170.0f, 21.0f}}


@interface S1BaseURLViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *baseURLField;

@end

@implementation S1BaseURLViewController

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
	// Do any additional setup after loading the view.
    self.title = NSLocalizedString(@"请求地址设置", @"Login");
    
    self.baseURLField = [[UITextField alloc] initWithFrame:_DEFAULT_TEXT_FIELD_RECT];
    self.baseURLField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"BaseURL"];
    self.baseURLField.textColor = [UIColor colorWithRed:56.0f/255.0f green:84.0f/255.0f blue:135.0f/255.0f alpha:1.0f];
    self.baseURLField.tag = 99;
    self.baseURLField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.baseURLField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.baseURLField.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:UITextFieldTextDidChangeNotification object:nil];
    __weak typeof(self) myself = self;
    
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = NSLocalizedString(@"请求地址", @"URL");
                if (cell.contentView.subviews.count < 2) {
                    CGRect toFrame = _DEFAULT_TEXT_FIELD_RECT;
                    toFrame.size.width = cell.contentView.bounds.size.width - toFrame.origin.x - 30.0f;
                    myself.baseURLField.frame = toFrame;
                    [cell.contentView addSubview:myself.baseURLField];
                }
            }];
        }];
    }];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NSUserDefaults standardUserDefaults] setValue:self.baseURLField.text forKey:@"BaseURL"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSNotification *notification = [NSNotification notificationWithName:@"S1BaseURLMayChangedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
}


#pragma mark - 

- (void)textDidChange:(NSNotification *)aNotification
{
    UITextField *textField = [aNotification object];
    NSLog(@"%@", textField);
}

- (BOOL)validator:(NSString *)text
{
    NSString *pattern = @"http://[\\w\\d\\.]+";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSRange range = [re rangeOfFirstMatchInString:text options:NSMatchingReportProgress range:NSMakeRange(0, text.length)];
    return range.location != NSNotFound;
}


@end
