//
//  MvrItem.h
//  Network+Storage
//
//  Created by ∞ on 13/09/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kMvrItemTitleMetadataKey @"MvrTitle"

@class MvrItemStorage;

@interface MvrItem : NSObject {
	MvrItemStorage* storage;
	NSString* type;
	NSMutableDictionary* metadata;
	NSMutableDictionary* autocache;
}

- (id) init;
- (id) initWithStorage:(MvrItemStorage*) s type:(NSString*) type metadata:(NSDictionary*) m;

+ (void) registerClass;
+ (NSSet*) supportedTypes; // abstract

+ (void) registerClass:(Class) c forType:(NSString*) type;
+ (Class) classForType:(NSString*) c;

+ itemWithStorage:(MvrItemStorage*) s type:(NSString*) t metadata:(NSDictionary*) m;

@property(readonly, retain) MvrItemStorage* storage;

@property(copy) NSString* title;
@property(copy) NSString* type;
@property(readonly) NSMutableDictionary* metadata;

- (id) produceExternalRepresentation; // abstract

// -- - --
// Autocache support

// The autocache is a set of key-value pairs that can be removed from memory at any time.
// You can use the accessors below to set and get objects from the cache, but if you try to access the cached object for a key that does not exist, it will be automatically recreated by calling -objectForEmptyCacheKey: (which in turn calls -objectForEmpty<Key>CacheKey if it exists).
// Additionally, the cache is guaranteed never to empty itself unless there is also a storage object attached to this item. In practice, this means that you can set an object in the cache in a constructor calling -init and it won't be lost until the item has had a chance to offload itself to disk. Make sure you're able to reconstruct the object from the storage and it'll automatically be managed.
- (id) cachedObjectForKey:(NSString*) key;
- (void) setCachedObject:(id) object forKey:(NSString*) key;
- (void) removeCachedObjectForKey:(NSString*) key;

// Called when a cached object is requested for an empty key. If - (id) objectForEmpty<Key>CacheKey; exists on self, it's called and its value returned. Otherwise, it returns nil.
// Example: @"image" calls -objectForEmptyImageCacheKey.
// Returning nil from this object does not alter the cache, and makes the cachedObjectForKey: call return nil.
- (id) objectForEmptyCacheKey:(NSString*) key;

@end
