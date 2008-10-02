//
//  imageCell.h
//  FixMyStreet
//
//  Created by Matthew on 29/09/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface imageCell : UITableViewCell {
	UILabel* labelView;
	UIImageView* imageView;
}

@property (nonatomic, retain) UIImageView* imageView;
@property (nonatomic, retain) UILabel* labelView;

-(void)setData:(UIImage *)newImage;

@end
