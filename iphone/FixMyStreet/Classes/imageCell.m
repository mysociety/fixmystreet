//
//  imageCell.m
//  FixMyStreet
//
//  Created by Matthew on 29/09/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import "imageCell.h"


@implementation imageCell

@synthesize imageView;
@synthesize labelView;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) {
		
		UIFont *font = [UIFont boldSystemFontOfSize:17.0];
		UILabel *newLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		newLabel.backgroundColor = [UIColor clearColor];
		//newLabel.backgroundColor = [UIColor whiteColor];
		newLabel.opaque = YES;
		newLabel.textColor = [UIColor blackColor];
		newLabel.text = @"Take photo";
		newLabel.highlightedTextColor = [UIColor whiteColor];
		newLabel.font = font;
		newLabel.textAlignment = UITextAlignmentLeft; // default
		self.labelView = newLabel;
		[self.contentView addSubview:newLabel];
		[newLabel release];
		self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
		[self.contentView addSubview:self.imageView];
		//[self.imageView release];

    }
    return self;
}

-(void)setData:(UIImage *)newImage {
	//CGSize imageSize = newImage.size;
	//float w = 100.0 / imageSize.width;
	//imageView.frame = CGRectMake(150,5,100,imageSize.height * w);
	//CGRect contentRect = self.contentView.bounds;
	//contentRect.size = CGSizeMake(contentRect.size.width, imageSize.height*w);
	imageView.image = newImage;
	//self.contentView.bounds = contentRect;
}

-(void)layoutSubviews {
	[super layoutSubviews];
	if (imageView.image) {
		CGSize imageSize = imageView.image.size;
		float w = 100.0 / imageSize.width;
		imageView.frame = CGRectMake(10,0,100,imageSize.height * w);
		labelView.frame = CGRectMake(120, imageSize.height * w / 2, 200, 20);
	CGRect contentRect = self.contentView.bounds;
	contentRect.size = CGSizeMake(contentRect.size.width, imageSize.height*w);
 self.contentView.bounds = contentRect;
	} else {
		labelView.frame = CGRectMake(10, 0, 200, 44);
	}
}

- (void)dealloc {
	[imageView dealloc];
	[labelView dealloc];
	[super dealloc];
}

@end
