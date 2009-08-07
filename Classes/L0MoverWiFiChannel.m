//
//  L0MoverWiFiChannel.m
//  Mover
//
//  Created by ∞ on 10/06/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "L0MoverWiFiChannel.h"
#import <MuiKit/MuiKit.h>

static inline CFMutableDictionaryRef L0CFDictionaryCreateMutableForObjects() {
	return CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

@interface L0MoverWiFiChannel ()

@property(assign, setter=privateSetApplicationVersion:) double applicationVersion;
@property(copy, setter=privateSetUserVisibleApplicationVersion:) NSString* userVisibleApplicationVersion;
@property(copy, setter=privateSetUniquePeerIdentifier:) NSString* uniquePeerIdentifier;

@end


@implementation L0MoverWiFiChannel

@synthesize service;
@synthesize applicationVersion, userVisibleApplicationVersion, uniquePeerIdentifier;

- (id) initWithScanner:(L0MoverWiFiScanner*) sc netService:(NSNetService*) s;
{
	if (self = [super init]) {
		scanner = sc;
		
		service = [s retain];
		itemsBeingSentByConnection = L0CFDictionaryCreateMutableForObjects();
		finalizingConnections = [NSMutableSet new];
		
		NSData* txtData = [s TXTRecordData];
		if (txtData) {
			NSDictionary* info = [NSNetService dictionaryFromTXTRecordData:txtData];
			L0Log(@"Parsing info dictionary %@ for peer %@", info, self);
			
			NSData* appVersionData;
			if (appVersionData = [info objectForKey:kL0BonjourPeerApplicationVersionKey])
				self.applicationVersion = [[[[NSString alloc] initWithData:appVersionData encoding:NSUTF8StringEncoding] autorelease] doubleValue];
			
			NSData* userVisibleAppVersionData;
			if (userVisibleAppVersionData = [info objectForKey:kL0BonjourPeerUserVisibleApplicationVersionKey])
				self.userVisibleApplicationVersion = [[[NSString alloc] initWithData:userVisibleAppVersionData encoding:NSUTF8StringEncoding] autorelease];
			
			NSData* uniqueIdentifierData;
			if (uniqueIdentifierData = [info objectForKey:kL0BonjourPeerUniqueIdentifierKey])
				self.uniquePeerIdentifier = [[[NSString alloc] initWithData:uniqueIdentifierData encoding:NSUTF8StringEncoding] autorelease];
			else {
				L0Log(@"For backwards compatibility, a unique ID has been autogenerated for this peer. (Given that he lacks one, he probably doesn't have multichannel support, so we're pretty safe here.)");
				self.uniquePeerIdentifier = [[L0UUID UUID] stringValue];
			}
			
			L0Log(@"App version found: %f.", self.applicationVersion);
			L0Log(@"User visible app version found: %@", self.userVisibleApplicationVersion);
		}
	}
	
	return self;
}

- (void) dealloc;
{
	[service release];
	for (BLIPConnection* c in (NSDictionary*) itemsBeingSentByConnection) {
		[c setDelegate:nil];
		[c close];
	}
	
	CFRelease(itemsBeingSentByConnection);
	[finalizingConnections release];
	
	[userVisibleApplicationVersion release];
	[uniquePeerIdentifier release];
	
	[super dealloc];
}

- (NSString*) name;
{
	return [service name];
}

#pragma mark -
#pragma mark Sending items

- (BOOL) sendItemToOtherEndpoint:(L0MoverItem*) item;
{
	if (CFDictionaryContainsValue(itemsBeingSentByConnection, item))
		return NO;
	
	BLIPConnection* connection = [[BLIPConnection alloc] initToNetService:service];
	[connection open];
	
	CFDictionarySetValue(itemsBeingSentByConnection, connection, item);
	
	[scanner.service channel:self willSendItemToOtherEndpoint:item];
	connection.delegate = self;
	BLIPRequest* request = [item contentsAsBLIPRequest];
	[connection sendRequest:request];
	[connection release];
	
	return YES;
}

- (void) connection: (BLIPConnection*)connection receivedResponse: (BLIPResponse*)response;
{
	L0MoverItem* i = (L0MoverItem*) CFDictionaryGetValue(itemsBeingSentByConnection, connection);
	if (i)
		[scanner.service channel:self didSendItemToOtherEndpoint:i];
	
	// we assume it's fine. for now.
	[finalizingConnections addObject:connection];
	[connection close];
}

- (void) connectionDidClose: (TCPConnection*)connection;
{
	L0Log(@"%@", connection);
}

- (void) connection: (TCPConnection*)connection failedToOpen: (NSError*)error;
{
	L0Log(@"%@, %@", connection, error);
	L0MoverItem* i = (L0MoverItem*) CFDictionaryGetValue(itemsBeingSentByConnection, connection);
	if (i)
		[scanner.service channel:self didSendItemToOtherEndpoint:i];
	
	CFDictionaryRemoveValue(itemsBeingSentByConnection, connection);
}

- (BOOL) connectionReceivedCloseRequest: (BLIPConnection*)connection;
{
	L0Log(@"%@", connection);
	
	L0MoverItem* i = (L0MoverItem*) CFDictionaryGetValue(itemsBeingSentByConnection, connection);
	if (![finalizingConnections containsObject:connection])
		[scanner.service channel:self didSendItemToOtherEndpoint:i];
	
	[finalizingConnections removeObject:connection];
	CFDictionaryRemoveValue(itemsBeingSentByConnection, connection);
	
	return YES;
}

- (void) connection: (BLIPConnection*)connection closeRequestFailedWithError: (NSError*)error;
{
	L0Log(@"%@, %@", connection, error);
	[connection close];
}

@end
