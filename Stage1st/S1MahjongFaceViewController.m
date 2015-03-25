//
//  S1MahjongFaceViewController.m
//  Stage1st
//
//  Created by Zheng Li on 3/16/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1MahjongFaceViewController.h"
#import "UIImageView+AFNetworking.h"

@interface S1MahjongFaceViewController ()

@property (nonatomic, strong) NSDictionary *mahjongMap;

@end

@implementation S1MahjongFaceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setFrame:CGRectMake(0, 0, 320, 200)];
    [self.view setBackgroundColor:[S1Global color5]];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MahjongMap" ofType:@"plist"];
    self.mahjongMap = [NSDictionary dictionaryWithContentsOfFile:path];
    NSArray *keys = [self.mahjongMap allKeys];
    NSUInteger index = 0;
    NSUInteger row = 0;
    for (NSString *key in keys) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(index * 50 + 19,row * 50 + 9, 32, 32)];
        NSString *baseURLString = [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"];
        NSString *prefix = [NSString stringWithFormat:@"%@static/image/smiley/", baseURLString];
        NSString *lastPath = [self.mahjongMap valueForKey:key];
        NSLog(@"%@", [prefix stringByAppendingString:lastPath]);
        [imageView setImageWithURL:[NSURL URLWithString:[prefix stringByAppendingString:lastPath]]];
        [self.view addSubview:imageView];
        index += 1;
        if (index == 6) {
            index = 0;
            row += 1;
        }
        if (row == 4) {
            break;
        }
    }
    
    // Do any additional setup after loading the view.
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
