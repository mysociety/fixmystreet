//
//  EditingTableViewCell.h
//  FixMyStreet
//
//  Created by Matthew on 20/10/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EditingTableViewCell : UITableViewCell {
	UITextField *textField;
}
@property (nonatomic, retain) UITextField *textField;

@end
