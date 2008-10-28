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
@synthesize image, latitude, longitude, subject, name, email, phone;

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

	// NSMutableArray *tempMutableCopy = [[[NSUserDefaults standardUserDefaults] objectForKey:kRestoreLocationKey] mutableCopy];
	name = [[NSUserDefaults standardUserDefaults] stringForKey:@"Name"];
	email = [[NSUserDefaults standardUserDefaults] stringForKey:@"Email"];
	phone = [[NSUserDefaults standardUserDefaults] stringForKey:@"Phone"];
	subject = [[NSUserDefaults standardUserDefaults] stringForKey:@"Subject"];

//	NSData *imageData = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Image"] mutableCopy];
//	if (imageData != nil)
//		image = (UIImage *)[NSKeyedUnarchiver unarchiveObjectWithData:imageData];
//	[imageData release];

	latitude = [[NSUserDefaults standardUserDefaults] stringForKey:@"Latitude"];
	longitude = [[NSUserDefaults standardUserDefaults] stringForKey:@"Longitude"];
//	NSData *locationData = [[NSUserDefaults standardUserDefaults] objectForKey:@"Location"];
//	if (locationData != nil)
//		location = (CLLocation *)[NSUnarchiver unarchiveObjectWithData:locationData];
//	[locationData release];

	[window addSubview:[navigationController view]];
	[window makeKeyAndVisible];

//	NSArray *keys = [NSArray arrayWithObjects:@"Name", @"Email", @"Phone", nil];
//	NSArray *values = [NSArray arrayWithObjects:name, email, phone, nil];
//	NSDictionary *dictionary = [NSDictionary dictionaryWithObjects:values forKeys:keys];
//	[[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
//	[[NSUserDefaults standardUserDefaults] synchronize];
//	[keys release];
//	[values release];
//	[dictionary release];
}

- (void)dealloc {
    [window release];
	[navigationController release];
//	[viewController release];
	[image release];
	[latitude release];
	[longitude release];
	[subject release];
	[name release];
	[email release];
	[phone release];
    [super dealloc];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Save state in case they're just in the middle of a phone call...
	[[NSUserDefaults standardUserDefaults] setObject:name forKey:@"Name"];
	[[NSUserDefaults standardUserDefaults] setObject:email forKey:@"Email"];
	[[NSUserDefaults standardUserDefaults] setObject:phone forKey:@"Phone"];
	[[NSUserDefaults standardUserDefaults] setObject:subject forKey:@"Subject"];

// XXX image crashes (restarting app. still has image showing?! and then quitting crashes, either way)
// Location just doesn't seem to work
	
//	if (image) {
//		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//		NSString *imageFile = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"saved.image"];
//		[NSKeyedArchiver archiveRootObject:image toFile:imageFile];
//	}
//	NSData *imageData = [NSKeyedArchiver archivedDataWithRootObject:image];
//	[[NSUserDefaults standardUserDefaults] setObject:imageData forKey:@"Image"];
//	[imageData release];

	[[NSUserDefaults standardUserDefaults] setObject:latitude forKey:@"Latitude"];
	[[NSUserDefaults standardUserDefaults] setObject:longitude forKey:@"Longitude"];
//	NSData *locationData = [NSKeyedArchiver archivedDataWithRootObject:location];
//	[[NSUserDefaults standardUserDefaults] setObject:locationData forKey:@"Location"];
//	[locationData release];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
}

// Report stuff
-(void)uploadReport {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	uploading = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
	UIColor *bg = [[UIColor alloc] initWithRed:0 green:0 blue:0 alpha:0.5];
	uploading.backgroundColor = bg;
	[bg release];
	UIActivityIndicatorView *spinny = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	spinny.center = CGPointMake(160, 160);
	[uploading addSubview:spinny];
	[spinny startAnimating];
	[self.navigationController.view addSubview:uploading];
	[spinny release];
	
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
	
	if (latitude) {
//		NSString* latitude = [NSString stringWithFormat:@"%f", location.coordinates.latitude];
//		NSString* longitude = [NSString stringWithFormat:@"%f", location.coordinates.longitude];
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
	
	returnData = [[NSMutableData alloc] init];
	[NSURLConnection connectionWithRequest:request delegate:self];
//	NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[returnData appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[uploading removeFromSuperview];

	NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSASCIIStringEncoding];

	if ([returnString isEqualToString:@"SUCCESS"]) {
		subject = nil;
		self.image = nil;
		[(InputTableViewController*)self.navigationController.visibleViewController reportUploaded:YES];
		UIAlertView *v = [[UIAlertView alloc] initWithTitle:@"Your report has been received" message:@"Check your email for the next step" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[v show];
		[v release];
	} else {
		// Pop up alert box with return error(s)
		NSArray *errors = [returnString componentsSeparatedByString:@"ERROR:"];
		NSString *errorString = [[NSString alloc] init];
		for (int i=1; i<[errors count]; i++) {
			NSString *error = [errors objectAtIndex:i];
			errorString = [errorString stringByAppendingFormat:@"\xE2\x80\xA2 %@", error];
		}
		UIAlertView *v = [[UIAlertView alloc] initWithTitle:@"Upload failed" message:errorString delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[v show];
		[v release];
	}
}

@end
