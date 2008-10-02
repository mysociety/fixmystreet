//
//  EditSubjectViewController.h
//  FixMyStreet
//
//  Created by Matthew on 01/10/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SubjectTableViewCell;

@interface EditSubjectViewController : UITableViewController <UITextFieldDelegate> {
	SubjectTableViewCell *subjectCell;
}

-(void)updateSummary:(NSString*)summary;

@end
