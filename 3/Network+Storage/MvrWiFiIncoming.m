//
//  MvrWiFiIncoming.m
//  Network+Storage
//
//  Created by ∞ on 15/09/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MvrWiFiIncoming.h"

#import <MuiKit/MuiKit.h>
#import "MvrItem.h"

@implementation MvrWiFiIncoming

@synthesize progress, item, cancelled;

- (void) dealloc;
{
	self.item = nil;
	[super dealloc];
}

@end

@implementation MvrWiFiIncoming (MvrKVOUtilityMethods)

- (void) observeUsingDispatcher:(L0KVODispatcher*) d invokeAtItemChange:(SEL) itemSel atCancelledChange:(SEL) cancelSel;
{
	[d observe:@"item" ofObject:self usingSelector:itemSel options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld];
	[d observe:@"cancelled" ofObject:self usingSelector:cancelSel options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld];
}

- (void) observeUsingDispatcher:(L0KVODispatcher*) d invokeAtItemOrCancelledChange:(SEL) itemAndCancelSel;
{
	[self observeUsingDispatcher:d invokeAtItemChange:itemAndCancelSel atCancelledChange:itemAndCancelSel];
}

- (void) endObservingUsingDispatcher:(L0KVODispatcher*) d;
{
	[d endObserving:@"cancelled" ofObject:self];
	[d endObserving:@"item" ofObject:self];
}

@end
