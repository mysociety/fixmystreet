//
//  subjectTableViewCell.m
//  FixMyStreet
//
//  Created by Matthew on 26/09/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

#import "SubjectTableViewCell.h"

@implementation SubjectTableViewCell

@synthesize textField;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) {
        textField = [[UITextField alloc] initWithFrame:CGRectZero];
		textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		textField.font = [UIFont systemFontOfSize:20];
		textField.placeholder = @"Summary";
		textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
		textField.clearButtonMode = UITextFieldViewModeWhileEditing;
		textField.returnKeyType = UIReturnKeyDone;
		[self addSubview:textField];
    }
    return self;
}

-(void)layoutSubviews {
	textField.frame = CGRectInset(self.contentView.bounds, 20, 0);
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
}

- (void)dealloc {
	[textField release];
    [super dealloc];
}

@end
