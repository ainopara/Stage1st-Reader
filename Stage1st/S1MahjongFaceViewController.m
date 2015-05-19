//
//  S1MahjongFaceViewController.m
//  Stage1st
//
//  Created by Zheng Li on 3/16/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1MahjongFaceViewController.h"
#import "UIButton+AFNetworking.h"

@interface S1MahjongFaceViewController ()

@property (nonatomic, strong) NSDictionary *mahjongMap;
@property (nonatomic, strong) NSMutableArray *buttonKeys;

@end

#pragma mark -

@implementation S1MahjongFaceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.buttonKeys = [[NSMutableArray alloc] init];
    [self.view setBackgroundColor:[S1Global color5]];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MahjongMap" ofType:@"plist"];
    self.mahjongMap = [NSDictionary dictionaryWithContentsOfFile:path];
    NSArray *keys = [self.mahjongMap allKeys];
    NSUInteger index = 0;
    NSUInteger row = 0;
    for (NSString *key in keys) {
        UIButton *button = [self mahjongFaceButtonForKey:key];
        [button setFrame:CGRectMake(index * 50 + 10,row * 50 , 50, 50)];
        [button addTarget:self action:@selector(mahjongFacePressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.buttonKeys addObject:key];
        button.tag = [self.buttonKeys indexOfObject:key];
        [self.view addSubview:button];
        
        index += 1;
        if (index == 6) {
            index = 0;
            row += 1;
        }
        if (row == 3) {
            break;
        }
    }
}

#pragma mark Event

- (void)mahjongFacePressed:(UIButton *)button
{
    NSLog(@"%ld", (long)button.tag);
    NSLog(@"%@", self.buttonKeys[button.tag]);
}

#pragma mark Helper

- (NSURL *)URLForKey:(NSString *)key {
    NSString *prefix = [[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] stringByAppendingString:@"static/image/smiley/"];
    NSString *mahjongURLString = [prefix stringByAppendingString:[self.mahjongMap valueForKey:key]];
    return [NSURL URLWithString:mahjongURLString];
}

- (NSMutableURLRequest *)requestForKey:(NSString *)key {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self URLForKey:key]];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    return  request;
}

- (UIButton *)mahjongFaceButtonForKey:(NSString *)key {
    UIButton *button = [[UIButton alloc] init];
    button.contentMode = UIViewContentModeCenter;
    
    __weak UIButton *weakButton = button;
    [button setImageForState:UIControlStateNormal withURLRequest:[self requestForKey:key] placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        __strong UIButton *strongButton = weakButton;
        UIImage * theImage = [UIImage imageWithCGImage:image.CGImage scale:1.0 orientation:UIImageOrientationUp];
        [strongButton setImage:theImage forState:UIControlStateNormal];
    } failure:^(NSError *error) {
        NSLog(@"Unexpected failure when request mahjong face image");
    }];

    return button;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
