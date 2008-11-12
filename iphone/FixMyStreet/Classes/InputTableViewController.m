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
#import "AboutViewController.h"

@implementation InputTableViewController

//@synthesize image;
//@synthesize imagCell;
//@synthesize reportSummary;

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle {
    if (self = [super initWithNibName:nibName bundle:nibBundle]) {
		self.title = @"FixMyStreet";
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
	[self enableSubmissionButton];
}

// Implement viewDidLoad to do additional setup after loading the view.
- (void)viewDidLoad {
    [super viewDidLoad];

	backButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonSystemItemCancel target:nil action:nil];
	self.navigationItem.backBarButtonItem = backButton;

	UIBarButtonItem* rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Report" style:UIBarButtonItemStyleDone target:self action:@selector(uploadReport) ];
	rightBarButtonItem.enabled = NO;
	self.navigationItem.rightBarButtonItem = rightBarButtonItem;
	[rightBarButtonItem release];

	// Let's start trying to find our location...
	[MyCLController sharedInstance].delegate = self;
	[[MyCLController sharedInstance] startUpdatingLocation];

	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	if (delegate.image) {
		UIImage *newImage = [[UIImage alloc] initWithData:delegate.image];
		imageView.image = newImage;
		[newImage release];
	}

}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	if (delegate.name || delegate.email || delegate.phone)
		return 4;
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

-(void)enableSubmissionButton {
	[actionsToDoView reloadData];
	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	if (delegate.image && delegate.latitude && delegate.subject && delegate.subject.length) {
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
		} else {
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		cell.text = @"Take photo";
		actionTakePhotoCell = cell;
	} else if (indexPath.section == 2) {
		if (delegate.latitude) {
			cell.accessoryView = nil;
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else if ([MyCLController sharedInstance].updating) {
			UIActivityIndicatorView* activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[activityView startAnimating];
			cell.accessoryView = activityView;
			[activityView release];
		} else {
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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
	} else if (indexPath.section == 3) {
		if (delegate.name && delegate.name.length && delegate.email && delegate.email.length) {
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else {
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		cell.text = @"Your details";
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
		EditSubjectViewController* editSubjectViewController = [[EditSubjectViewController alloc] initWithNibName:@"EditSubjectView" bundle:nil];
		[editSubjectViewController setAll:delegate.subject viewTitle:@"Edit summary" placeholder:@"Summary" keyboardType:UIKeyboardTypeDefault capitalisation:UITextAutocapitalizationTypeSentences];
		[self.navigationController pushViewController:editSubjectViewController animated:YES];
		[editSubjectViewController release];
	} else if (indexPath.section == 3) {
		[self gotoSettings:nil firstTime:NO];
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
	picker.allowsImageEditing = NO;
	[self presentModalViewController:picker animated:YES];
}

- (void)viewDidAppear:(BOOL)animated {
	backButton.title = @"Cancel";
}

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
	[backButton release];
	[subjectLabel release];
	[subjectContent release];
    [super dealloc];
}


// UIImagePickerControllerDelegate prototype

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)newImage editingInfo:(NSDictionary *)editingInfo {
	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	NSData *imageData  = UIImageJPEGRepresentation(newImage, 0.8);	
	delegate.image = imageData;

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
//	delegate.location = location;
	delegate.latitude = [NSString stringWithFormat:@"%f", location.coordinate.latitude];
	delegate.longitude = [NSString stringWithFormat:@"%f", location.coordinate.longitude];

	[self enableSubmissionButton];
}

-(void)newError:(NSString *)text {
}

// Buttons

// I realise this flips the navbar too, but can't seem to do it nicely with a container parent, and not really that important!
-(IBAction)gotoAbout:(id)sender {
	backButton.title = @"Back";
	AboutViewController* aboutViewController = [[AboutViewController alloc] initWithNibName:@"AboutView" bundle:nil];
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration: 0.75];
	[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.navigationController.view cache:YES];
	[self.navigationController pushViewController:aboutViewController animated:NO];
	[UIView commitAnimations];
	[aboutViewController release];
}

-(IBAction)gotoSettings:(id)sender firstTime:(BOOL)firstTime {
	backButton.title = @"Done";
	SettingsViewController* settingsViewController = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
	if (firstTime)
		settingsViewController.firstTime = firstTime; 
	[self.navigationController pushViewController:settingsViewController animated:YES];
	[settingsViewController release];
}

-(void)uploadReport {
	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	if (!delegate.name || !delegate.email) {
		[self gotoSettings:nil firstTime:YES];
	} else {
		[delegate uploadReport];
	}
}

-(void)reportUploaded:(BOOL)success {
	if (success)
		imageView.image = nil;
	[self enableSubmissionButton];	
}

@end

