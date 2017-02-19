//
//  SettingsViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/13/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "SettingsViewController.h"
#import "GSStaticTableViewBuilder.h"
#import "CloudKitManager.h"
#import <Crashlytics/Answers.h>
#import <YapDatabase/YapDatabaseCloudKit.h>
#import <SafariServices/SafariServices.h>
#import <AcknowList/AcknowList-Swift.h>

@interface SettingsViewController ()

@property (weak, nonatomic) IBOutlet UILabel *usernameDetail;
@property (weak, nonatomic) IBOutlet UILabel *fontSizeDetail;
@property (weak, nonatomic) IBOutlet UISwitch *displayImageSwitch;
@property (weak, nonatomic) IBOutlet UILabel *keepHistoryDetail;
@property (weak, nonatomic) IBOutlet UISwitch *removeTailsSwitch;
@property (weak, nonatomic) IBOutlet UILabel *versionDetail;
@property (weak, nonatomic) IBOutlet UISwitch *precacheSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *nightModeSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *forcePortraitSwitch;

@property (weak, nonatomic) IBOutlet UITableViewCell *forumOrderCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *fontSizeCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *keepHistoryCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *iCloudSyncCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *forcePortraitCell;

@property (assign, nonatomic) CGFloat offset;

@end

@implementation SettingsViewController

#pragma mark - Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (IS_IPAD) {
        //UIDropShadowView has a fixed corner radius.
        self.navigationController.view.layer.cornerRadius  = 5.0;
        self.navigationController.view.layer.masksToBounds = YES;
        self.navigationController.view.superview.backgroundColor = [UIColor clearColor];
    }

    self.forumOrderCell.textLabel.text = NSLocalizedString(@"SettingView_Forum_Order_Custom", @"Forum Order");

    self.displayImageSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"Display"];
    self.forcePortraitSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"ForcePortraitForPhone"];
    if (IS_IPAD) {
        self.forcePortraitCell.hidden = YES;
    }
    
    self.removeTailsSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"RemoveTails"];
    self.precacheSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"PrecacheNextPage"];
    self.nightModeSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"NightMode"];
    
    self.versionDetail.text = [self applicationVersion];

    self.navigationItem.title = NSLocalizedString(@"SettingView_NavigationBar_Title", @"Settings");
    
    self.fontSizeCell.textLabel.text = NSLocalizedString(@"SettingView_Font_Size", @"Font Size");
    self.fontSizeCell.detailTextLabel.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
    self.fontSizeCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    self.fontSizeCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    self.keepHistoryCell.textLabel.text = NSLocalizedString(@"SettingView_HistoryLimit", @"History Limit");
    self.keepHistoryCell.detailTextLabel.text = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
    self.keepHistoryCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    self.keepHistoryCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    self.offset = 0;
    self.tableView.delegate = self;
    [self.tableView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceivePaletteChangeNotification:) name:@"APPaletteDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cloudKitStateChanged:) name:YapDatabaseCloudKitStateChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveLoginStatusChangeNotification:) name:@"DZLoginStatusDidChangeNotification" object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self _resetLoginStatus];

    self.fontSizeDetail.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
    self.keepHistoryDetail.text = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];

    [self _updateiCloudStatus];
    [self didReceivePaletteChangeNotification:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [CrashlyticsKit setObjectValue:@"SettingsViewController" forKey:@"lastViewController"];
}

- (void)dealloc {
    [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Pull To Close

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (self.offset < -36) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
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

#pragma mark - Navigation

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 7) {
        if (IS_IPAD) {
            return 0;
        }
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
        controller.title = NSLocalizedString(@"SettingView_Font_Size", @"Font Size");
        [controller setCompletionHandler:^(NSString *key) {
            [[NSUserDefaults standardUserDefaults] setValue:key forKey:@"FontSize"];
        }];
        [self.navigationController pushViewController:controller animated:YES];
    } else if (indexPath.section == 0 && indexPath.row == 4) {
        NSString *selectedKey = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
        NSArray *keys = @[NSLocalizedString(@"SettingView_HistoryLimit_3days", @"3 days"), NSLocalizedString(@"SettingView_HistoryLimit_1week", @"1 week"), NSLocalizedString(@"SettingView_HistoryLimit_2weeks", @"2 weeks"), NSLocalizedString(@"SettingView_HistoryLimit_1month", @"1 month"), NSLocalizedString(@"SettingView_HistoryLimit_3months", @"3 months"), NSLocalizedString(@"SettingView_HistoryLimit_6months", @"6 months"), NSLocalizedString(@"SettingView_HistoryLimit_1year", @"1 year"), NSLocalizedString(@"SettingView_HistoryLimit_Forever", @"Forever")];
        
        GSSingleSelectionTableViewController *controller = [[GSSingleSelectionTableViewController alloc] initWithKeys:keys andSelectedKey:selectedKey];
        controller.title = NSLocalizedString(@"SettingView_HistoryLimit", @"HistoryLimit");
        [controller setCompletionHandler:^(NSString *key) {
            [[NSUserDefaults standardUserDefaults] setValue:[S1Global HistoryLimitString2Number:key] forKey:@"HistoryLimit"];
        }];
        [self.navigationController pushViewController:controller animated:YES];
    } else if (indexPath.section == 0 && indexPath.row == 0) {
        LoginViewController *viewController = [[LoginViewController alloc] initWithNibName:nil bundle:nil];
        [self presentViewController:viewController animated:YES completion:NULL];
    } else if (indexPath.section == 0 && indexPath.row == 9) {
        [self.navigationController pushViewController:[[AdvancedSettingsViewController alloc] initWithNibName:nil bundle:nil] animated:YES];
    } else if (indexPath.section == 2 && indexPath.row == 2) {
#ifdef DEBUG
        InMemoryLogViewController *logViewController = [[InMemoryLogViewController alloc] initInMemoryLogger:[InMemoryLogger shared]];
        [self.navigationController pushViewController:logViewController animated:YES];
#else
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:@"https://ainopara.github.io/stage1st-reader-EULA.html"]];
        [self presentViewController:safariViewController animated:YES completion:NULL];
#endif
    } else if (indexPath.section == 2 && indexPath.row == 3) {
        NSString *acknowledgmentPlistFilePath = [[NSBundle mainBundle] pathForResource:@"Pods-Stage1st-acknowledgements" ofType:@"plist"];
        AcknowListViewController *acknowledgementViewController = [[AcknowListViewController alloc] initWithAcknowledgementsPlistPath:acknowledgmentPlistFilePath];
        [self.navigationController pushViewController:acknowledgementViewController animated:YES];
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
    [[ColorManager shared] switchPalette:sender.on == YES ? PaletteTypeNight : PaletteTypeDay];
}

- (IBAction)switchForcePortrait:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"ForcePortraitForPhone"];
}

#pragma mark - Notification

- (void)didReceivePaletteChangeNotification:(NSNotification *)notification {
    [self.displayImageSwitch setOnTintColor:[[ColorManager shared] colorForKey:@"appearance.switch.tint"]];
    [self.removeTailsSwitch setOnTintColor:[[ColorManager shared] colorForKey:@"appearance.switch.tint"]];
    [self.precacheSwitch setOnTintColor:[[ColorManager shared] colorForKey:@"appearance.switch.tint"]];
    [self.forcePortraitSwitch setOnTintColor:[[ColorManager shared] colorForKey:@"appearance.switch.tint"]];
    [self.nightModeSwitch setOnTintColor:[[ColorManager shared] colorForKey:@"appearance.switch.tint"]];
    [self.navigationController.navigationBar setBarTintColor:[[ColorManager shared]  colorForKey:@"appearance.navigationbar.bartint"]];
    [self.navigationController.navigationBar setTintColor:[[ColorManager shared]  colorForKey:@"appearance.navigationbar.tint"]];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [[ColorManager shared] colorForKey:@"appearance.navigationbar.title"],
                                                 NSFontAttributeName:[UIFont boldSystemFontOfSize:17.0],}];
    [self.navigationController.navigationBar setBarStyle: [[ColorManager shared] isDarkTheme] ? UIBarStyleBlack : UIBarStyleDefault];
}

- (void)cloudKitStateChanged:(NSNotification *)notification {
    [self _updateiCloudStatus];
}

- (void)didReceiveLoginStatusChangeNotification:(NSNotification *)notification {
    [self _resetLoginStatus];
}

#pragma mark - Helper

- (void)_updateiCloudStatus {
    NSString *titleString;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSync"]) {
        titleString = NSLocalizedString(@"SettingView_CloudKit_Status_Off", @"Off");
    } else {
        NSUInteger suspendCount = [MyDatabaseManager.cloudKitExtension suspendCount];
        
        NSUInteger inFlightCount = 0;
        NSUInteger queuedCount = 0;
        [MyDatabaseManager.cloudKitExtension getNumberOfInFlightChangeSets:&inFlightCount queuedChangeSets:&queuedCount];
        
        switch ([MyCloudKitManager state]) {
            case CKManagerStateInit:
                titleString = NSLocalizedString(@"SettingView_CloudKit_Status_Init", @"Init");
                break;
            case CKManagerStateSetup:
                titleString = NSLocalizedString(@"SettingView_CloudKit_Status_Setup", @"Setup");
                break;
            case CKManagerStateFetching:
                titleString = NSLocalizedString(@"SettingView_CloudKit_Status_Fetch", @"Fetch");
                break;
            case CKManagerStateUploading:
                titleString = [NSString stringWithFormat:@"(%lu-%lu)", (unsigned long)inFlightCount, (unsigned long)queuedCount];
                titleString = [NSLocalizedString(@"SettingView_CloudKit_Status_Upload", @"Upload") stringByAppendingString:titleString];
                break;
            case CKManagerStateReady:
                titleString = NSLocalizedString(@"SettingView_CloudKit_Status_Ready", @"Ready");
                break;
            case CKManagerStateRecovering:
                titleString = NSLocalizedString(@"SettingView_CloudKit_Status_Recover", @"Recover");
                break;
            case CKManagerStateHalt:
                titleString = [NSString stringWithFormat:@"(%lu)", (unsigned long)suspendCount];
                titleString = [NSLocalizedString(@"SettingView_CloudKit_Status_Halt", @"Halt") stringByAppendingString:titleString];
                break;
            default:
                break;
        }
    }
    
    self.iCloudSyncCell.detailTextLabel.text = titleString;
}

- (void)_resetLoginStatus {
    NSString *inLoginStateID = [[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"];
    if (inLoginStateID != nil && [inLoginStateID isKindOfClass:[NSString class]]) {
        self.usernameDetail.text = inLoginStateID;
    } else {
        self.usernameDetail.text = NSLocalizedString(@"SettingView_Not_Login_State_Mark", @"");
    }
}

@end
