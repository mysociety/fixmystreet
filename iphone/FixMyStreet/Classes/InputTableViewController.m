//
//  InputTableViewController.m
//  FixMyStreet
//
//  Created by Matthew on 26/09/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import "InputTableViewController.h"
#import "subjectTableViewCell.h"
#import "imageCell.h"
#import "FixMyStreetAppDelegate.h"
#import "EditSubjectViewController.h"
#import "Report.h"

@implementation InputTableViewController

//@synthesize image;
//@synthesize imagCell;
//@synthesize reportSummary;

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle {
    if (self = [super initWithNibName:nibName bundle:nibBundle]) {
		self.title = @"FixMyStreet";
		// These seem to work better in viewDidLoad
		// actionsToDoView.sectionHeaderHeight = 0.0;
		// self.navigationItem.backBarButtonItem.title = @"Foo";
	}
	return self;
}

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {
    }
    return self;
}
*/

- (void)viewWillAppear:(BOOL)animated {
    //[super viewWillAppear:animated];
    [self enableSubmissionButton];
}

// Implement viewDidLoad to do additional setup after loading the view.
- (void)viewDidLoad {
    [super viewDidLoad];
	actionsToDoView.sectionFooterHeight = 0;

	UIBarButtonItem* backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonSystemItemCancel target:nil action:nil];
	self.navigationItem.backBarButtonItem = backBarButtonItem;
	[backBarButtonItem release];

	UIBarButtonItem* rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Report" style:UIBarButtonSystemItemSave target:nil action:nil];
	rightBarButtonItem.enabled = NO;
	self.navigationItem.rightBarButtonItem = rightBarButtonItem;
	[rightBarButtonItem release];

	// Let's start trying to find our location...
	[MyCLController sharedInstance].delegate = self;
	[[MyCLController sharedInstance] startUpdatingLocation];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return nil;
	// Possible section==2 heading to make summary clearer once entered?
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//	return 44.0f;
//}

-(void)enableSubmissionButton {
	[actionsToDoView reloadData];
	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	if (delegate.image && delegate.location && delegate.subject) {
		self.navigationItem.rightBarButtonItem.enabled = YES;
	} else {
		self.navigationItem.rightBarButtonItem.enabled = NO;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	static NSString *CellIdentifier;
	UITableViewCell *cell;
	FixMyStreetAppDelegate* delegate = [[UIApplication sharedApplication] delegate];
	
	// Possible editing of subject within main view (I think I prefer it as is, though need to make display clearer somehow)
	// And possible display of selected image within cell somewhere/somehow (I like how Contacts does it, but haven't
	// managed that so far

	/* if (indexPath.section == 2) {
		CellIdentifier = @"CellText";
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			//CGRect frame = CGRectMake(0, 0, 250, 44);
			cell = [[[subjectTableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
			//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			//UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(1.0, 1.0, 250, 44)];
			//textField.placeholder = @"Subject";
			// [textField addTarget:self action:nil forControlEvents:UIControlEventValueChanged];
			//cell.accessoryView = textField;
			//[textField release];
		}
	} else */
	/* if (indexPath.section == 0) {
		CellIdentifier = @"CellImage";
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[imageCell alloc] initWithFrame:CGRectMake(0, 0, 400, 44) reuseIdentifier:CellIdentifier] autorelease];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	} else { */

	CellIdentifier = @"Cell";
	cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	
	//}

	if (indexPath.section == 0) {
		if (delegate.image) {
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		}
		cell.text = @"Take photo";
		actionTakePhotoCell = cell;
	} else if (indexPath.section == 1) {
		if (delegate.location) {
			cell.accessoryView = nil;
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else if ([MyCLController sharedInstance].updating) {
			UIActivityIndicatorView* activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[activityView startAnimating];
			cell.accessoryView = activityView;
			[activityView release];
		}
		cell.text = @"Fetch location";
		actionFetchLocationCell = cell;
	} else if (indexPath.section == 2) {
		if (delegate.subject) {
			cell.text = delegate.subject;
			cell.textColor = [UIColor blackColor];
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else {
			cell.text = @"Short summary of problem";
			cell.textColor = [UIColor grayColor];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		actionSummaryCell = cell;
	} else {
		cell.text = @"Eh?";
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 0) {
		[self addPhoto:nil];	
	} else if (indexPath.section == 1) {
		[[MyCLController sharedInstance].locationManager startUpdatingLocation];
	} else if (indexPath.section == 2) {
		UIViewController* editSubjectViewController = [[EditSubjectViewController alloc] initWithNibName:@"EditSubjectView"	bundle:nil];
		[self.navigationController pushViewController:editSubjectViewController animated:YES];
		[editSubjectViewController release];
	}
}

-(IBAction)addPhoto:(id) sender {
	BOOL cameraAvailable = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
	BOOL photosAvailable = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
	if (!cameraAvailable && !photosAvailable) {
		UITableViewCell *cell = [actionsToDoView cellForRowAtIndexPath:0]; // XXX
		cell.text = @"No photo mechanism available";
		return;
	}
	UIImagePickerController* picker = [[UIImagePickerController alloc] init];
	if (cameraAvailable) {
		picker.sourceType = UIImagePickerControllerSourceTypeCamera;
	} else {
		picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	}
	picker.delegate = self;
	picker.allowsImageEditing = YES;
	[self presentModalViewController:picker animated:YES];
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
}
*/
/*
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
*/

// Check this, I can't remember if you need to release nib things.
- (void)dealloc {
	[imageView release];
	[actionTakePhotoCell release];
	[actionFetchLocationCell release];
	[actionSummaryCell release];
	[actionsToDoView release];
	[settingsButton release];
    [super dealloc];
}


// UIImagePickerControllerDelegate prototype

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)newImage editingInfo:(NSDictionary *)editingInfo {
	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	delegate.image = newImage;

	imageView.image = newImage;
	
	[[picker parentViewController] dismissModalViewControllerAnimated:YES];
	[picker release];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[[picker parentViewController] dismissModalViewControllerAnimated:YES];
	[picker release];
}

// MyCLControllerDelegate

-(void)newLocationUpdate:(NSString *)text {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Hey" message:text delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];

	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	delegate.location = text;
	
	[self enableSubmissionButton];
}

-(void)newError:(NSString *)text {
}

// Settings

-(IBAction)gotoSettings:(id)sender {
}

@end

