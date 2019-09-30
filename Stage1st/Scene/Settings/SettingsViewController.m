//
//  SettingsViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/13/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "SettingsViewController.h"
#import "GSStaticTableViewBuilder.h"
#import <Crashlytics/Answers.h>
#import <YapDatabase/YapDatabaseCloudKit.h>
#import <SafariServices/SafariServices.h>
#import <AcknowList/AcknowList-Swift.h>
@import CrashlyticsLogger;
#import "Stage1st-Swift.h"

@implementation SettingsViewController

#pragma mark - Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (IS_IPAD) {
        //UIDropShadowView has a fixed corner radius.
        self.navigationController.view.layer.cornerRadius = 5.0;
        self.navigationController.view.layer.masksToBounds = YES;
        self.navigationController.view.superview.backgroundColor = [UIColor clearColor];
    }

    self.forumOrderCell.textLabel.text = NSLocalizedString(@"SettingsViewController.Forum_Order_Custom", @"Forum Order");

    [self setupInitialValue];

    if (IS_IPAD) {
        self.forcePortraitCell.hidden = YES;
    }
        
    self.versionDetail.text = [self applicationVersion];

    self.navigationItem.title = NSLocalizedString(@"SettingsViewController.NavigationBar_Title", @"Settings");
    
    self.fontSizeCell.textLabel.text = NSLocalizedString(@"SettingsViewController.Font_Size", @"Font Size");
    self.fontSizeCell.detailTextLabel.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
    self.fontSizeCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    self.fontSizeCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    self.keepHistoryCell.textLabel.text = NSLocalizedString(@"SettingsViewController.HistoryLimit", @"History Limit");
    self.keepHistoryCell.detailTextLabel.text = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
    self.keepHistoryCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    self.keepHistoryCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    NSUInteger totalCacheSize = [[NSURLCache sharedURLCache] currentDiskUsage];
    double prettyPrintedCacheSize = (totalCacheSize / (102 * 1024)) / 10.0;
    self.imageCacheCell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f MiB", prettyPrintedCacheSize];

    // Pull to dismiss
    self.offset = 0;
    self.tableView.delegate = self;
    if (@available(iOS 13.0, *)) {
        // iOS 13 has a better solution fot this
    } else {
        [self.tableView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceivePaletteChangeNotification:)
                                                 name:@"APPaletteDidChangeNotification"
                                               object:nil];

    [self setupObservation];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.fontSizeDetail.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
    self.keepHistoryDetail.text = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];

    [self didReceivePaletteChangeNotification:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [CrashlyticsKit setObjectValue:@"SettingsViewController" forKey:@"lastViewController"];
}

- (void)dealloc {
    if (@available(iOS 13.0, *)) {
        // iOS 13 has a better solution fot this
    } else {
        [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Pull To Close

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (@available(iOS 13.0, *)) {
        // iOS 13 has a better solution fot this
    } else {
        if (self.offset < -36) {
            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentOffset"]) {
        self.offset = [[change objectForKey:@"new"] CGPointValue].y + 64;
    }
}

#pragma mark - Orientation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ForcePortraitForPhone"]) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            return UIInterfaceOrientationMaskPortrait;
        }
    }
    return [super supportedInterfaceOrientations];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ForcePortraitForPhone"]) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            return UIInterfaceOrientationPortrait;
        }
    }
    return [super preferredInterfaceOrientationForPresentation];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (IS_IPAD && indexPath.section == 0 && indexPath.row == 7) {
        return 0.0;
    }

    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"[Settings] select: %@", indexPath);
    
    if (indexPath.section == 0 && indexPath.row == 2) {
        NSArray *keys;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            keys = @[@"15px", @"17px", @"19px"];
        } else {
            keys = @[@"18px", @"20px", @"22px"];
        }
        GSSingleSelectionTableViewController *controller = [[GSSingleSelectionTableViewController alloc] initWithKeys:keys andSelectedKey:[[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"]];
        controller.title = NSLocalizedString(@"SettingsViewController.Font_Size", @"Font Size");
        [controller setCompletionHandler:^(NSString *key) {
            [[NSUserDefaults standardUserDefaults] setValue:key forKey:@"FontSize"];
        }];
        [self.navigationController pushViewController:controller animated:YES];
    } else if (indexPath.section == 0 && indexPath.row == 4) {
        NSString *selectedKey = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
        NSArray *keys = @[
            NSLocalizedString(@"SettingsViewController.HistoryLimit.3days", @"3 days"),
            NSLocalizedString(@"SettingsViewController.HistoryLimit.1week", @"1 week"),
            NSLocalizedString(@"SettingsViewController.HistoryLimit.2weeks", @"2 weeks"),
            NSLocalizedString(@"SettingsViewController.HistoryLimit.1month", @"1 month"),
            NSLocalizedString(@"SettingsViewController.HistoryLimit.3months", @"3 months"),
            NSLocalizedString(@"SettingsViewController.HistoryLimit.6months", @"6 months"),
            NSLocalizedString(@"SettingsViewController.HistoryLimit.1year", @"1 year"),
            NSLocalizedString(@"SettingsViewController.HistoryLimit.Forever", @"Forever")
        ];
        
        GSSingleSelectionTableViewController *controller = [[GSSingleSelectionTableViewController alloc] initWithKeys:keys andSelectedKey:selectedKey];
        controller.title = NSLocalizedString(@"SettingsViewController.HistoryLimit", @"HistoryLimit");
        [controller setCompletionHandler:^(NSString *key) {
            [[NSUserDefaults standardUserDefaults] setValue:[S1Global HistoryLimitString2Number:key] forKey:@"HistoryLimit"];
        }];
        [self.navigationController pushViewController:controller animated:YES];
    } else if (indexPath.section == 0 && indexPath.row == 0) {
        LoginViewController *viewController = [[LoginViewController alloc] initWithNibName:nil bundle:nil];
        [self presentViewController:viewController animated:YES completion:NULL];
    } else if (indexPath.section == 0 && indexPath.row == 9) {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [self clearWebKitCache];
        NSUInteger totalCacheSize = [self totalCacheSize];
        double prettyPrintedCacheSize = (totalCacheSize / (102 * 1024)) / 10.0;
        self.imageCacheCell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f MiB", prettyPrintedCacheSize];
    } else if (indexPath.section == 0 && indexPath.row == 10) {
        [self.navigationController pushViewController:[[AdvancedSettingsViewController alloc] initWithNibName:nil bundle:nil] animated:YES];
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        [self.navigationController pushViewController:[[CloudKitViewController alloc] initWithNibName:nil bundle:nil] animated:YES];
    } else if (indexPath.section == 2 && indexPath.row == 2) {
#ifdef DEBUG
        [self pushLogViewer];
#else
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:@"https://ainopara.github.io/stage1st-reader-EULA.html"]];
        [self presentViewController:safariViewController animated:YES completion:NULL];
#endif
    } else if (indexPath.section == 2 && indexPath.row == 3) {
        [self.navigationController pushViewController:[self acknowledgementListViewController] animated:YES];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Actions

- (IBAction)back:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)switchDisplayImage:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"Display"];
}

- (IBAction)switchRemoveTails:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"RemoveTails"];
}

- (IBAction)switchPrecache:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"PrecacheNextPage"];
}

- (IBAction)switchNightMode:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"NightMode"];
    [AppEnvironment.current.colorManager switchPalette:sender.on == YES ? PaletteTypeNight : PaletteTypeDay];
}

- (IBAction)switchForcePortrait:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"ForcePortraitForPhone"];
}

#pragma mark - Notification

- (void)didReceivePaletteChangeNotification:(NSNotification *)notification {
    [self.displayImageSwitch setOnTintColor:[AppEnvironment.current.colorManager colorForKey:@"appearance.switch.tint"]];
    [self.removeTailsSwitch setOnTintColor:[AppEnvironment.current.colorManager colorForKey:@"appearance.switch.tint"]];
    [self.precacheSwitch setOnTintColor:[AppEnvironment.current.colorManager colorForKey:@"appearance.switch.tint"]];
    [self.forcePortraitSwitch setOnTintColor:[AppEnvironment.current.colorManager colorForKey:@"appearance.switch.tint"]];
    [self.nightModeSwitch setOnTintColor:[AppEnvironment.current.colorManager colorForKey:@"appearance.switch.tint"]];
    [self.navigationController.navigationBar setBarTintColor:[AppEnvironment.current.colorManager colorForKey:@"appearance.navigationbar.bartint"]];
    [self.navigationController.navigationBar setTintColor:[AppEnvironment.current.colorManager colorForKey:@"appearance.navigationbar.tint"]];
    [self.navigationController.navigationBar setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [AppEnvironment.current.colorManager colorForKey:@"appearance.navigationbar.title"],
        NSFontAttributeName:[UIFont boldSystemFontOfSize:17.0],
    }];
    [self.navigationController.navigationBar setBarStyle: [AppEnvironment.current.colorManager isDarkTheme] ? UIBarStyleBlack : UIBarStyleDefault];
}

@end
