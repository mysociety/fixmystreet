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

@synthesize window, navigationController; //, viewController;
@synthesize image, location, subject, name, email, phone;

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	InputTableViewController *inputTableViewController = [[InputTableViewController alloc] initWithNibName:@"MainViewController" bundle:[NSBundle mainBundle]];
//	InputTableViewController *inputTableViewController = [[InputTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
	//RootViewController *rootViewController = [[RootViewController alloc] i
	// So we had our root view in a nib file, but we're creating our navigation controller programmatically. Ah well.
	UINavigationController *aNavigationController = [[UINavigationController alloc] initWithRootViewController:inputTableViewController];
//	UINavigationController *aNavigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
	self.navigationController = aNavigationController;
	[aNavigationController release];
	[inputTableViewController release];
//	[rootViewController release];
	
	[window addSubview:[navigationController view]];
	[window makeKeyAndVisible];
	
	// Need to fetch defaults here, plus anything saved when we quit last time
}

- (void)dealloc {
    [window release];
	[navigationController release];
//	[viewController release];
    [super dealloc];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Save state in case they're just in the middle of a phone call...
	
}

// Report stuff
-(void)uploadReport {
	// Not yet working - do something spinny here
	// UIActivityIndicatorView *spinny = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	// [spinny startAnimating];
	// [spinny release];
	
	// Get the phone's unique ID
	UIDevice *dev = [UIDevice currentDevice];
	NSString *uniqueId = dev.uniqueIdentifier;
	
	NSString *urlString = @"http://matthew.fixmystreet.com/import";
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
	[request setURL:[NSURL URLWithString: urlString]];
	[request setHTTPMethod: @"POST"];
	
	NSString *stringBoundary = @"0xMyLovelyBoundary";
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",stringBoundary];
	[request addValue:contentType forHTTPHeaderField: @"Content-Type"];
	
	//setting up the body:
	NSMutableData *postBody = [NSMutableData data];
	
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"service\"\r\n\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[@"iPhone" dataUsingEncoding:NSASCIIStringEncoding]];
	
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"phone_id\"\r\n\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[uniqueId dataUsingEncoding:NSASCIIStringEncoding]];
	
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"subject\"\r\n\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[subject dataUsingEncoding:NSASCIIStringEncoding]];

	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"name\"\r\n\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[name dataUsingEncoding:NSASCIIStringEncoding]];
	
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"email\"\r\n\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[email dataUsingEncoding:NSASCIIStringEncoding]];
	
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"phone\"\r\n\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
	[postBody appendData:[phone dataUsingEncoding:NSASCIIStringEncoding]];
	
	if (location) {
		NSString* latitude = [NSString stringWithFormat:@"%f", location.coordinate.latitude];
		NSString* longitude = [NSString stringWithFormat:@"%f", location.coordinate.longitude];
		[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
		[postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"lat\"\r\n\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
		[postBody appendData:[latitude dataUsingEncoding:NSASCIIStringEncoding]];
	
		[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
		[postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"lon\"\r\n\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
		[postBody appendData:[longitude dataUsingEncoding:NSASCIIStringEncoding]];
	}

	if (image) {
		NSData *imageData  = UIImageJPEGRepresentation(image, 0.8);	
		[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
		[postBody appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"photo\"; filename=\"from_phone.jpeg\"\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
		[postBody appendData:[[NSString stringWithString:@"Content-Type: image/jpeg\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
		[postBody appendData:[[NSString stringWithString:@"Content-Transfer-Encoding: binary\r\n\r\n"] dataUsingEncoding:NSASCIIStringEncoding]];
		[postBody appendData:imageData];
	}

	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",stringBoundary] dataUsingEncoding:NSASCIIStringEncoding]];
	
	[request setHTTPBody: postBody];
	
	NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
	NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSASCIIStringEncoding];
    
	// For now, just pop up alert box with return data
	UIAlertView *v = [[UIAlertView alloc] initWithTitle:@"Return" message:returnString delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[v show];
	[v release];
//	NSLog(@"Returned string is: %s", returnString);

}

@end
