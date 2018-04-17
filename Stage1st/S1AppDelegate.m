//
//  S1AppDelegate.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1AppDelegate.h"
#import "S1TopicListViewController.h"
#import "NavigationControllerDelegate.h"
#import "S1Topic.h"
#import "S1Tracer.h"
#import "S1Parser.h"
#import "CloudKitManager.h"
#import "DatabaseManager.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <Reachability/Reachability.h>
@import UserNotifications;

S1AppDelegate *MyAppDelegate;

@implementation S1AppDelegate

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        // Store global reference
        MyAppDelegate = self;

        [self setupLogging];
        
    }
    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Crashlytics
#ifndef DEBUG
    [Fabric with:@[[Crashlytics class]]];
#endif
    // Setup
    [self setup];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    // Start database & cloudKit (in order)
    [DatabaseManager initialize];
    if ([userDefaults boolForKey:@"EnableSync"]) {
        [CloudKitManager initialize];
    }

    // Migrate to v3.4
    NSArray *array = [userDefaults valueForKey:@"Order"];
    NSArray *array0 =[array firstObject];
    NSArray *array1 =[array lastObject];
    if([array0 indexOfObject:@"模玩专区"] == NSNotFound && [array1 indexOfObject:@"模玩专区"] == NSNotFound) {
        DDLogDebug(@"Update Order List");
        NSString *path = [[NSBundle mainBundle] pathForResource:@"InitialOrder" ofType:@"plist"];
        NSArray *order = [NSArray arrayWithContentsOfFile:path];
        [userDefaults setObject:order forKey:@"Order"];
        [userDefaults removeObjectForKey:@"UserID"];
        [userDefaults removeObjectForKey:@"UserPassword"];
    }
    
    // Migrate to v3.6
    [S1Tracer upgradeDatabase];
    
    // Migrate to v3.7
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && [[userDefaults objectForKey:@"FontSize"] isEqualToString:@"17px"]) {
        [userDefaults setObject:@"18px" forKey:@"FontSize"];
    }

    // Migrate to v3.8 and later
    [self migrate];
    
    if ([userDefaults boolForKey:@"EnableSync"]) {
        [application registerForRemoteNotifications];
    }

    // Reachability
    _reachability = [Reachability reachabilityForInternetConnection];
    [_reachability startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];

    // Setup Window
    S1NavigationViewController *navigationController = [[S1NavigationViewController alloc] initWithNavigationBarClass:nil toolbarClass:nil];
    self.navigationDelegate = [[NavigationControllerDelegate alloc] initWithNavigationController:navigationController];
    navigationController.delegate = self.navigationDelegate;
    navigationController.viewControllers = @[[[S1TopicListViewController alloc] initWithNibName:nil bundle:nil]];
    navigationController.navigationBarHidden = YES;

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = navigationController;
    [self.window makeKeyAndVisible];

    // Appearence
    [[ColorManager shared] updateGlobalAppearance];

    [self.navigationDelegate setUpGagat];


#ifdef DEBUG
    DDLogVerbose(@"Dump user defaults: %@", [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);
#endif

    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self notifyCleaning];
}

#pragma mark - URL Scheme

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    DDLogDebug(@"[URL Scheme] %@ from %@", url, options[UIApplicationOpenURLOptionsSourceApplicationKey]);
    
    //Open Specific Topic Case
    NSDictionary *queryDict = [S1Parser extractQuerysFromURLString:[url absoluteString]];
    if ([[url host] isEqualToString:@"open"]) {
        NSString *topicIDString = [queryDict valueForKey:@"tid"];
        
        if (topicIDString) {
            NSNumber *topicID = [NSNumber numberWithInteger:[topicIDString integerValue]];
            S1Topic *topic = [[[AppEnvironment current] dataCenter] tracedWithTopicID:[topicIDString integerValue]];
            if (topic == nil && topicID != nil) {
                topic = [[S1Topic alloc] initWithTopicID:topicID];
            }
            [self pushContentViewControllerForTopic:topic];
            return YES;
        }
    }

    return YES;
}

#pragma mark - Background Sync

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    DDLogInfo(@"[Backgournd Fetch] fetch called");
    completionHandler(UIBackgroundFetchResultNoData);
    // TODO: user forum notification can be fetched here, then send a local notification to user.
}

#pragma mark - Hand Off

- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType {
    // TODO: Show an alert to tell user we are restoring state from hand off here.
    return YES;
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray *))restorationHandler {
    DDLogDebug(@"Receive Hand Off: %@", userActivity.userInfo);
    NSNumber *topicID = [userActivity.userInfo valueForKey:@"topicID"];
    if (topicID != nil) {
        S1Topic *topic = [[[AppEnvironment current] dataCenter] tracedWithTopicID:topicID.integerValue];
        if (topic != nil) {
            NSNumber *lastViewedPage = [userActivity.userInfo valueForKey:@"page"];
            if (lastViewedPage) {
                topic = [topic copy];
                topic.lastViewedPage = lastViewedPage;
            }
        } else {
            topic = [[S1Topic alloc] initWithTopicID:topicID];
            NSNumber *lastViewedPage = [userActivity.userInfo valueForKey:@"page"];
            if (lastViewedPage) {
                topic.lastViewedPage = lastViewedPage;
            }
        }
        [self pushContentViewControllerForTopic:topic];
        return YES;
    } else {
        NSString *urlString = [userActivity.webpageURL absoluteString];
        S1Topic *parsedTopic = [S1Parser extractTopicInfoFromLink:urlString];
        if (parsedTopic.topicID) {
            S1Topic *tracedTopic = [[[AppEnvironment current] dataCenter] tracedWithTopicID:parsedTopic.topicID.integerValue];
            if (tracedTopic) {
                NSNumber *lastViewedPage = parsedTopic.lastViewedPage;
                if (lastViewedPage) {
                    tracedTopic = [tracedTopic copy];
                    tracedTopic.lastViewedPage = lastViewedPage;
                }
                [self pushContentViewControllerForTopic:tracedTopic];
                return YES;
            } else {
                [self pushContentViewControllerForTopic:parsedTopic];
                return YES;
            }
        }
    }
    return NO;
}

#pragma mark - Reachability

- (void)reachabilityChanged:(NSNotification *)notification {
    Reachability *reachability = notification.object;
    if ([reachability isReachableViaWiFi]) {
        DDLogDebug(@"[Reachability] WIFI: display picture");
    } else {
        DDLogDebug(@"[Reachability] WWAN: display placeholder");
    }
}

#pragma mark - Helper

- (void)pushContentViewControllerForTopic:(S1Topic *)topic {
    id rootvc = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    if ([rootvc isKindOfClass:[UINavigationController class]] && topic != nil) {
        S1ContentViewController *contentViewController = [[S1ContentViewController alloc] initWithTopic:topic dataCenter:[[AppEnvironment current] dataCenter]];
        [(UINavigationController *)rootvc pushViewController:contentViewController animated:YES];
    }
}

@end
