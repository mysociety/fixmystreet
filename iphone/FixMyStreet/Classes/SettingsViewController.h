//
//  SettingsViewController.h
//  FixMyStreet
//
//  Created by Matthew on 20/10/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsViewController : UITableViewController {
	UILabel *nameLabel;
	UILabel *nameCurrent;
	UILabel *emailLabel;
	UILabel *emailCurrent;
	UILabel *phoneLabel;
	UILabel *phoneCurrent;
	
	BOOL firstTime;
}

@property (nonatomic, assign) BOOL firstTime;

@end
