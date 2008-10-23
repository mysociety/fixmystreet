//
//  SettingsViewController.m
//  FixMyStreet
//
//  Created by Matthew on 20/10/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import "SettingsViewController.h"
#import "FixMyStreetAppDelegate.h"
#import "EditSubjectViewController.h"

@implementation SettingsViewController

@synthesize firstTime;

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {
    }
    return self;
}
*/

// Implement viewDidLoad to do additional setup after loading the view.
- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = @"Edit settings";
	self.tableView.sectionHeaderHeight = 27.0;
	self.tableView.sectionFooterHeight = 0.0;
	self.tableView.scrollEnabled = NO;
	
	UIBarButtonItem* backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonSystemItemCancel target:nil action:nil];
	self.navigationItem.backBarButtonItem = backBarButtonItem;
	[backBarButtonItem release];
	
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.firstTime)
		return 3;
    return 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 3) {
		return 54.0;
	}
	return 44.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	if (indexPath.section == 3) {
		static NSString *CellIdentifier = @"InfoCell";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
			UITextView *blurb = [[UITextView alloc] initWithFrame:CGRectMake(10, 0, 280, 44)];
			blurb.font = [UIFont italicSystemFontOfSize:14];
			blurb.textAlignment = UITextAlignmentCenter;
			blurb.editable = NO;
			blurb.text = @"Please fill in your details, and\nwe'll remember them for next time";
			[cell.contentView addSubview:blurb];
			[blurb release];
		}
		return cell;
	}

    static NSString *CellIdentifier = @"Cell";
	FixMyStreetAppDelegate* delegate = [[UIApplication sharedApplication] delegate];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

	NSString *text, *placeholder;
	UILabel *label, *current;
	if (indexPath.section == 0) {
		text = delegate.name;
		if (!nameLabel) {
			nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,0,70,40)];
			nameLabel.font = [UIFont boldSystemFontOfSize:17];
			nameLabel.text = @"Name:";
			[cell.contentView addSubview:nameLabel];
		}
		label = nameLabel;
		if (!nameCurrent) {
			nameCurrent = [[UILabel alloc] initWithFrame:CGRectMake(80,0,190,40)];
			nameCurrent.font = [UIFont systemFontOfSize:17];
			[cell.contentView addSubview:nameCurrent];
		}
		current = nameCurrent;
		placeholder = @"Your name";
	} else if (indexPath.section == 1) {
		text = delegate.email;
		if (!emailLabel) {
			emailLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,0,70,40)];
			emailLabel.font = [UIFont boldSystemFontOfSize:17];
			emailLabel.text = @"Email:";
			[cell.contentView addSubview:emailLabel];
		}
		label = emailLabel;
		if (!emailCurrent) {
			emailCurrent = [[UILabel alloc] initWithFrame:CGRectMake(80,0,190,40)];
			emailCurrent.font = [UIFont systemFontOfSize:17];
			[cell.contentView addSubview:emailCurrent];
		}
		current = emailCurrent;
		placeholder = @"Your email";
	} else if (indexPath.section == 2) {
		text = delegate.phone;
		if (!phoneLabel) {
			phoneLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,0,70,40)];
			phoneLabel.font = [UIFont boldSystemFontOfSize:17];
			phoneLabel.text = @"Phone:";
			[cell.contentView addSubview:phoneLabel];
		}
		label = phoneLabel;
		if (!phoneCurrent) {
			phoneCurrent = [[UILabel alloc] initWithFrame:CGRectMake(80,0,190,40)];
			phoneCurrent.font = [UIFont systemFontOfSize:17];
			[cell.contentView addSubview:phoneCurrent];
		}
		current = phoneCurrent;
		placeholder = @"Your phone (optional)";
	}

	if (text) {
		label.hidden = NO;
		cell.text = nil;
		current.text = text;
		current.hidden = NO;
		// cell.accessoryType = UITableViewCellAccessoryCheckmark;
	} else {
		label.hidden = YES;
		current.hidden = YES;
		cell.text = placeholder;
		cell.textColor = [UIColor grayColor];
		// cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
		
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 3) {
		return;
	}

	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	EditSubjectViewController* editSubjectViewController = [[EditSubjectViewController alloc] initWithStyle:UITableViewStyleGrouped];
	if (indexPath.section == 0) {
		[editSubjectViewController setAll:delegate.name viewTitle:@"Edit name" placeholder:@"Your name" keyboardType:UIKeyboardTypeDefault capitalisation:UITextAutocapitalizationTypeWords];
	} else if (indexPath.section == 1) {
		[editSubjectViewController setAll:delegate.email viewTitle:@"Edit email" placeholder:@"Your email" keyboardType:UIKeyboardTypeEmailAddress capitalisation:UITextAutocapitalizationTypeNone];
	} else if (indexPath.section == 2) {
		[editSubjectViewController setAll:delegate.phone viewTitle:@"Edit phone" placeholder:@"Your phone number" keyboardType:UIKeyboardTypeNumbersAndPunctuation capitalisation:UITextAutocapitalizationTypeNone];
	}	

	[self.navigationController pushViewController:editSubjectViewController animated:YES];
	[editSubjectViewController release];
}

- (void)viewWillAppear:(BOOL)animated {
	[self.tableView reloadData];
//    [super viewWillAppear:animated];
}

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

- (void)dealloc {
	[nameLabel release];
	[emailLabel release];
	[phoneLabel release];
	[nameCurrent release];
	[emailCurrent release];
	[phoneCurrent release];
    [super dealloc];
}


@end

