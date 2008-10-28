//
//  AboutViewController.m
//  FixMyStreet
//
//  Created by Matthew on 23/10/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import "AboutViewController.h"

@implementation AboutViewController

/*
// Override initWithNibName:bundle: to load the view using a nib file then perform additional customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

// Implement viewDidLoad to do additional setup after loading the view.
- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = @"About";
	self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
	donateButton.font = [UIFont systemFontOfSize:32];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc {
    [super dealloc];
}

-(IBAction)donate:(id)sender {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.mysociety.org/donate/"]];  
}

@end
