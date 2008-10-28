//
//  AboutViewController.h
//  FixMyStreet
//
//  Created by Matthew on 23/10/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface AboutViewController : UIViewController {
	IBOutlet UIButton* donateButton;
}

-(IBAction)donate:(id)sender;

@end
