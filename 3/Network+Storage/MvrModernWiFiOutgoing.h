//
//  MvrWiFiOutgoingTransfer.h
//  Mover
//
//  Created by ∞ on 29/08/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MvrOutgoing.h"

@class MvrItem;
@class AsyncSocket;

#import "MvrPacketBuilder.h"

@interface MvrModernWiFiOutgoing : NSObject <MvrPacketBuilderDelegate, MvrOutgoing> {
	MvrItem* item;
	NSArray* addresses;
	
	AsyncSocket* socket;
	MvrPacketBuilder* builder;
	
	BOOL finished;
	
	float progress;
	
	unsigned long chunksPending;
	BOOL canFinish;
}

- (id) initWithItem:(MvrItem*) i toAddresses:(NSArray*) a;

@property(readonly, assign) BOOL finished;
@property(readonly, assign) float progress;

- (void) start;

@end
