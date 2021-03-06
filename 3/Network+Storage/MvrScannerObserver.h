//
//  MvrScannerObserver.h
//  Network+Storage
//
//  Created by ∞ on 16/09/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class L0KVODispatcher;

#import "MvrScanner.h"
#import "MvrChannel.h"
#import "MvrIncoming.h"
#import "MvrOutgoing.h"

@protocol MvrScannerObserverDelegate;

@interface MvrScannerObserver : NSObject {
	L0KVODispatcher* kvo;
	id <MvrScanner> scanner;
	id <MvrScannerObserverDelegate> delegate;
}

- (id) initWithScanner:(id <MvrScanner>) scanner delegate:(id <MvrScannerObserverDelegate>) delegate;

@end

@protocol MvrScannerObserverDelegate <NSObject>

- (void) scanner:(id <MvrScanner>) s didChangeJammedKey:(BOOL) jammed;
- (void) scanner:(id <MvrScanner>) s didChangeEnabledKey:(BOOL) enabled;

- (void) scanner:(id <MvrScanner>) s didAddChannel:(id <MvrChannel>) channel;
- (void) scanner:(id <MvrScanner>) s didRemoveChannel:(id <MvrChannel>) channel;			

- (void) channel:(id <MvrChannel>) c didBeginReceivingWithIncomingTransfer:(id <MvrIncoming>) incoming;
- (void) channel:(id <MvrChannel>) c didBeginSendingWithOutgoingTransfer:(id <MvrOutgoing>) outgoing;

- (void) outgoingTransferDidEndSending:(id <MvrOutgoing>) outgoing;

// i == nil if cancelled.
- (void) incomingTransfer:(id <MvrIncoming>) incoming didEndReceivingItem:(MvrItem*) i;

@end