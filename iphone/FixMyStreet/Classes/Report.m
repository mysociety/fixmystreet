//
//  Report.m
//  FixMyStreet
//
//  Created by Matthew on 29/09/2008.
//  Copyright 2008 UK Citizens Online Democracy. All rights reserved.
//

/*
#import "Report.h"

static Report *sharedReport = nil;

@implementation Report

@synthesize image, location, subject;

-(void)uploadReport {
}

// See "Creating a Singleton Instance" in the Cocoa Fundamentals Guide for more info

+ (Report *)sharedInstance {
    @synchronized(self) {
        if (sharedReport == nil) {
            [[self alloc] init]; // assignment not done here
        }
    }
    return sharedReport;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedReport == nil) {
            sharedReport = [super allocWithZone:zone];
            return sharedReport;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
*/
