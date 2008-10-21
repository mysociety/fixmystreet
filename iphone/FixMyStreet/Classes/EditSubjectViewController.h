//
//  EditSubjectViewController.h
//  FixMyStreet
//
//  Created by Matthew on 01/10/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EditingTableViewCell;

@interface EditSubjectViewController : UITableViewController <UITextFieldDelegate> {
	EditingTableViewCell *cell;
}

@property (nonatomic, retain) EditingTableViewCell *cell;

-(void)setAll:(NSString*)a viewTitle:(NSString*)b placeholder:(NSString*)c keyboardType:(UIKeyboardType)d capitalisation:(UITextAutocapitalizationType)e;
-(void)updateText:(NSString*)text;

@end
