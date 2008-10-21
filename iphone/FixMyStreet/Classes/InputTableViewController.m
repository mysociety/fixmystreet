//
//  InputTableViewController.m
//  FixMyStreet
//
//  Created by Matthew on 26/09/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import "InputTableViewController.h"
#import "SettingsViewController.h"
#import "FixMyStreetAppDelegate.h"
#import "EditSubjectViewController.h"

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

	UIBarButtonItem* rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Report" style:UIBarButtonSystemItemSave target:self action:@selector(uploadReport) ];
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
	// Possible section==1 heading to make summary clearer once entered?
	return nil;
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
	if (delegate.image && delegate.location && delegate.subject && delegate.subject.length) {
		self.navigationItem.rightBarButtonItem.enabled = YES;
	} else {
		self.navigationItem.rightBarButtonItem.enabled = NO;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	static NSString *CellIdentifier;
	UITableViewCell *cell;
	FixMyStreetAppDelegate* delegate = [[UIApplication sharedApplication] delegate];
	
	// Possible editing of subject within main view (I think I prefer it as is)
	// And possible display of selected image within cell somewhere/somehow (I like how Contacts does it, but haven't
	// managed that so far

	if (indexPath.section == 1) {
		CellIdentifier = @"CellText";
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			//CGRect frame = CGRectMake(0, 0, 250, 44);
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
			//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			//UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(1.0, 1.0, 250, 44)];
			//textField.placeholder = @"Subject";
			// [textField addTarget:self action:nil forControlEvents:UIControlEventValueChanged];
			//cell.accessoryView = textField;
			//[textField release];
		}
	} else {
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
	
	}

	if (indexPath.section == 0) {
		if (delegate.image) {
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		}
		cell.text = @"Take photo";
		actionTakePhotoCell = cell;
	} else if (indexPath.section == 2) {
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
	} else if (indexPath.section == 1) {
		if (delegate.subject && delegate.subject.length) {
			if (!subjectLabel) {
				subjectLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,0,70,40)];
				subjectLabel.font = [UIFont boldSystemFontOfSize:17];
				subjectLabel.text = @"Subject:";
				[cell.contentView addSubview:subjectLabel];
			}
			subjectLabel.hidden = NO;
			if (!subjectContent) {
				subjectContent = [[UILabel alloc] initWithFrame:CGRectMake(80,0,190,40)];
				subjectContent.font = [UIFont systemFontOfSize:17];
				[cell.contentView addSubview:subjectContent];
			}
			cell.text = nil;
			subjectContent.text = delegate.subject;
			subjectContent.hidden = NO;
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else {
			subjectContent.hidden = YES;
			subjectLabel.hidden = YES;
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
	} else if (indexPath.section == 2) {
		[[MyCLController sharedInstance].locationManager startUpdatingLocation];
	} else if (indexPath.section == 1) {
		FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		EditSubjectViewController* editSubjectViewController = [[EditSubjectViewController alloc] initWithNibName:@"EditSubjectView"	bundle:nil];
		[editSubjectViewController setAll:delegate.subject viewTitle:@"Edit summary" placeholder:@"Summary" keyboardType:UIKeyboardTypeDefault capitalisation:UITextAutocapitalizationTypeSentences];
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
	[subjectLabel release];
	[subjectContent release];
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

-(void)newLocationUpdate:(CLLocation *)location {
	//UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Hey" message:text delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	//[alert show];
	//[alert release];

	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	delegate.location = location;
	
	[self enableSubmissionButton];
}

-(void)newError:(NSString *)text {
}

// Buttons

-(IBAction)gotoSettings:(id)sender {
	UIBarButtonItem* backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonSystemItemCancel target:nil action:nil];
	self.navigationItem.backBarButtonItem = backBarButtonItem;
	[backBarButtonItem release];
		
	UIViewController* settingsViewController = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
	//	[self.navigationController pushViewController:settingsViewController animated:YES];
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration: 1];
	[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.navigationController.view cache:YES];
	[self.navigationController pushViewController:settingsViewController animated:NO];
	[UIView commitAnimations];
	[settingsViewController release];
}

-(void)uploadReport {
	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	if (!delegate.name || !delegate.email) {
		[self gotoSettings:nil];
	} else {
		[delegate uploadReport];
	}
}

@end

