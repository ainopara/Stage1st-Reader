//
//  S1AppDelegate.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1AppDelegate.h"
#import "S1RootViewController.h"
#import "S1TopicListViewController.h"
#import "S1URLCache.h"
#import "S1Tracer.h"
//#import "PDDebugger.h"

@implementation S1AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    //Pony Debugger
    /*
    PDDebugger *debugger = [PDDebugger defaultInstance];
    [debugger enableNetworkTrafficDebugging];
    [debugger enableViewHierarchyDebugging];
    [debugger forwardAllNetworkTraffic];
    //[debugger enableCoreDataDebugging];
    [debugger connectToURL:[NSURL URLWithString:@"ws://localhost:9000/device"]];
    */
    //User Defaults;
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"Order"]) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"InitialOrder" ofType:@"plist"];
        NSArray *order = [NSArray arrayWithContentsOfFile:path];
        [[NSUserDefaults standardUserDefaults] setValue:order forKey:@"Order"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"Display"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"Display"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"http://bbs.saraba1st.com/2b/" forKey:@"BaseURL"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"15px" forKey:@"FontSize"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@259200 forKey:@"HistoryLimit"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"AppendSuffix"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"AppendSuffix"];
    }
    //Migrate tracer to sql database
    [S1Tracer migrateTracerToDatabase];
    
    //Migrate to v3.4.0
    NSArray *array = [[NSUserDefaults standardUserDefaults] valueForKey:@"Order"];
    NSArray *array0 =[array firstObject];
    NSArray *array1 =[array lastObject];
    if([array0 indexOfObject:@"内野"] == NSNotFound && [array1 indexOfObject:@"内野"]== NSNotFound) {
        NSLog(@"Update Order List");
        NSString *path = [[NSBundle mainBundle] pathForResource:@"InitialOrder" ofType:@"plist"];
        NSArray *order = [NSArray arrayWithContentsOfFile:path];
        [[NSUserDefaults standardUserDefaults] setValue:order forKey:@"Order"];
        [[NSUserDefaults standardUserDefaults] setValue:@"http://bbs.saraba1st.com/2b/" forKey:@"BaseURL"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"UserID"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"UserPassword"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] isEqualToString:@"http://bbs.saraba1st.com/2b/"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"http://bbs.saraba1st.com/2b/" forKey:@"BaseURL"];
    }
    //URL Cache
    S1URLCache *URLCache = [[S1URLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                         diskCapacity:10 * 1024 * 1024
                                                             diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];
    
    //Appearence
    if (SYSTEM_VERSION_LESS_THAN(@"7")) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            [[UIToolbar appearance] setBackgroundImage:[UIImage imageNamed:@"Toolbar_background.png"] forToolbarPosition:UIToolbarPositionBottom barMetrics:UIBarMetricsDefault];
            [[UIToolbar appearance] setBackgroundImage:[UIImage imageNamed:@"Navigation.png"] forToolbarPosition:UIToolbarPositionTop barMetrics:UIBarMetricsDefault];
            [[UINavigationBar appearance] setBackgroundImage:[[UIImage imageNamed:@"Navigation.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 5, 0, 5)] forBarMetrics:UIBarMetricsDefault];
            [[UIBarButtonItem appearance] setBackgroundImage:[[UIImage imageNamed:@"Bar_item.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 5, 0, 5)] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [[UIBarButtonItem appearance] setBackButtonBackgroundImage:[[UIImage imageNamed:@"Back_button_item.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 14, 0, 7)] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [[UIBarButtonItem appearance] setBackgroundImage:[[UIImage imageNamed:@"Bar_item_highlighted.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 5, 0, 5)] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
            [[UIBarButtonItem appearance] setBackButtonBackgroundImage:[[UIImage imageNamed:@"Back_button_item_highlighted.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 14, 0, 7)] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        }
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            [[UIToolbar appearance] setBackgroundImage:[UIImage imageNamed:@"Toolbar_background.png"] forToolbarPosition:UIToolbarPositionBottom barMetrics:UIBarMetricsDefault];
        }
    } else {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            [[UIToolbar appearance] setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color1]] forToolbarPosition:UIToolbarPositionBottom barMetrics:UIBarMetricsDefault];//color2
            [[UINavigationBar appearance] setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color1]] forBarMetrics:UIBarMetricsDefault];
            [[UINavigationBar appearance] setTintColor:[S1GlobalVariables color3]];
        }
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            [[UIToolbar appearance] setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color1]] forToolbarPosition:UIToolbarPositionBottom barMetrics:UIBarMetricsDefault];//color2
            [[UINavigationBar appearance] setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color1]] forBarMetrics:UIBarMetricsDefault];
            [[UINavigationBar appearance] setTintColor:[S1GlobalVariables color3]];
        }

    }
    

    
    
    self.window.backgroundColor = [UIColor blackColor];
    S1TopicListViewController *controller = [[S1TopicListViewController alloc] init];
    S1RootViewController *rootVC = [[S1RootViewController alloc] initWithMasterViewController:controller];
    self.window.rootViewController = rootVC;
    
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
