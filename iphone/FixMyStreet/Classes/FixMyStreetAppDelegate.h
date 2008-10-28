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
//	UIViewController *viewController;
	UINavigationController *navigationController;

	// The report currently being entered.
	NSData* image;
	
	NSString* latitude;
	NSString* longitude;
	NSString* subject;

	NSString* name;
	NSString* email;
	NSString* phone;
	
	UIView *uploading;
	NSMutableData* returnData;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UINavigationController *navigationController;
//@property (nonatomic, retain) IBOutlet UIViewController *viewController;

@property (nonatomic, retain) NSData* image;
@property (nonatomic, retain) NSString* latitude;
@property (nonatomic, retain) NSString* longitude;
@property (nonatomic, retain) NSString* subject;
@property (nonatomic, retain) NSString* name;
@property (nonatomic, retain) NSString* email;
@property (nonatomic, retain) NSString* phone;

-(void)uploadReport;

@end

