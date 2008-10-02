//
//  EditSubjectViewController.m
//  FixMyStreet
//
//  Created by Matthew on 01/10/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import "EditSubjectViewController.h"
#import "SubjectTableViewCell.h"
#import "FixMyStreetAppDelegate.h"

@implementation EditSubjectViewController

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
	self.title = @"Edit summary";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return subjectCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	[subjectCell.textField becomeFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated {
    //[super viewWillAppear:animated];
	if (!subjectCell) {
		subjectCell = [[SubjectTableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"SubjectCell"];
		subjectCell.textField.delegate = self;
	}
	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	if (delegate.subject) {
		subjectCell.textField.text = delegate.subject;
	}
	[subjectCell.textField becomeFirstResponder];
}

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/

- (void)viewWillDisappear:(BOOL)animated {
	// On 2.0 this produces same effect as clicking Done, but not in 2.1?
	[subjectCell.textField resignFirstResponder];
}

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
	[subjectCell release];
    [super dealloc];
}


-(void)updateSummary:(NSString*)summary {
	FixMyStreetAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	if (summary.length) {
		delegate.subject = summary;
	} else {
		delegate.subject = nil;
	}
	[self.navigationController popViewControllerAnimated:YES];
}

-(BOOL)textFieldShouldReturn:(UITextField*)theTextField {
	//if (theTextField == summaryTextField) {
	[theTextField resignFirstResponder];
	[self updateSummary:theTextField.text];
	//}
	return YES;
}

@end

