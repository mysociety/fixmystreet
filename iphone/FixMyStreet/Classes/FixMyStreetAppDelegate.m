//
//  FixMyStreetAppDelegate.m
//  FixMyStreet
//
//  Created by Matthew on 25/09/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import "FixMyStreetAppDelegate.h"
#import "InputTableViewController.h"

@implementation FixMyStreetAppDelegate

@synthesize window, navigationController;
@synthesize image, location, subject;

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	InputTableViewController *inputTableViewController = [[InputTableViewController alloc] initWithNibName:@"MainViewController" bundle:[NSBundle mainBundle]];
//	InputTableViewController *inputTableViewController = [[InputTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
	// So we had our root view in a nib file, but we're creating our navigation controller programmatically. Ah well.
	UINavigationController *aNavigationController = [[UINavigationController alloc] initWithRootViewController:inputTableViewController];
	self.navigationController = aNavigationController;
	[aNavigationController release];
	[inputTableViewController release];
	
	UIView *controllersView = [navigationController view];
	[window addSubview:controllersView];
	[window makeKeyAndVisible];
	
	// Need to fetch defaults here, plus anything saved when we quit last time
}

- (void)dealloc {
    [window release];
	[navigationController release];
    [super dealloc];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Save state in case they're just in the middle of a phone call...
	
}

// Report stuff
-(void)uploadReport {
}

@end
