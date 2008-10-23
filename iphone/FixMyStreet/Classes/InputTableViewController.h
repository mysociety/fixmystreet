//
//  InputTableViewController.h
//  FixMyStreet
//
//  Created by Matthew on 26/09/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MyCLController.h"

@interface InputTableViewController : UIViewController <UINavigationControllerDelegate,UIImagePickerControllerDelegate,MyCLControllerDelegate> {
	IBOutlet UIImageView* imageView;
	IBOutlet UITableView* actionsToDoView;
	IBOutlet UIButton* settingsButton;
	UIBarButtonItem* backButton;

	// Not sure what I made these for
	UITableViewCell* actionTakePhotoCell;
	UITableViewCell* actionFetchLocationCell;
	UITableViewCell* actionSummaryCell;
	
	UILabel* subjectLabel;
	UILabel* subjectContent;
}

-(void)enableSubmissionButton;
-(void)uploadReport;
-(void)reportUploaded:(BOOL)success;

-(IBAction)addPhoto:(id) sender;
-(IBAction)gotoSettings:(id)sender firstTime:(BOOL)firstTime;
-(IBAction)gotoAbout:(id)sender;

// UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;

//MyCLControllerDelegate
-(void)newLocationUpdate:(CLLocation *)location;
-(void)newError:(NSString *)text;

@end
