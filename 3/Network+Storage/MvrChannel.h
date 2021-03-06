
#import <Foundation/Foundation.h>

@class MvrItem;

@protocol MvrChannel <NSObject>

- (NSString*) displayName;

- (void) beginSendingItem:(MvrItem*) item;

// Can be KVO'd. Contains id <MvrIncoming>s.
- (NSSet*) incomingTransfers;

// Can be KVO'd. Contains id <MvrOutgoing>s.
- (NSSet*) outgoingTransfers;

@end
