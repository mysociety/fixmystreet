//
//  FixMyStreetAppDelegate.h
//  FixMyStreet
//
//  Created by Matthew on 25/09/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import <UIKit/UIKit.h>

@class InputTableViewController;

@interface FixMyStreetAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
	UINavigationController *navigationController;

	// The report currently being entered.
	UIImage* image;
	NSString* location;
	NSString* subject;

}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UINavigationController *navigationController;

@property (nonatomic, retain) UIImage* image;
@property (nonatomic, retain) NSString* location;
@property (nonatomic, retain) NSString* subject;

-(void)uploadReport;

@end

