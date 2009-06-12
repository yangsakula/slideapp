//
//  L0MoverAdController.m
//  Mover
//
//  Created by ∞ on 12/06/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "L0MoverAdController.h"


@implementation L0MoverAdController

@synthesize superview, origin;

#if kL0MoverInsertAdvertising

L0ObjCSingletonMethod(sharedController)

- (void) start;
{
	if (view) return;
	
	view = [[ARRollerView requestRollerViewWithDelegate:self] retain];
}

- (void) stop;
{
	[view setDelegateToNil];
	[view removeFromSuperview];
	[view release]; view = nil;
}

#pragma mark -
#pragma mark Managing the ad view.

- (void)didReceiveAd:(ARRollerView*)adWhirlView;
{
	if (view.superview) return;
	
	CGRect frame = view.frame;
	frame.origin = self.origin;
	view.frame = frame;
	
	view.alpha = 0.0;
	[self.superview addSubview:view];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.7];
	view.alpha = 1.0;
	[UIView commitAnimations];
}

#pragma mark -
#pragma mark Administrivia

- (NSString*)adWhirlApplicationKey;
{
	// Does nothing at runtime, but triggers a build error if we've forgotten the key.
	NSAssert(kL0MoverAdWhirlKey != nil, @"Need to have the AdWhirl key to build with ads");
	return kL0MoverAdWhirlKey;
}

- (void) dealloc;
{
	[self stop];
	[super dealloc];
}

#else

+ sharedController { return nil; }
- (void) start {}

#endif


@end
