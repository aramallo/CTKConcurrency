/*
 * Author: Alejandro M. Ramallo
 * Copyright (c) Alejandro M. Ramallo. All rights reserved.
 *
 * The use and distribution terms for this software are covered by the
 * Eclipse Public License 1.0 <http://opensource.org/licenses/eclipse-1.0.php>
 * which can be found in the file epl-v10.html at the root of this distribution.
 * By using this software in any fashion, you are agreeing to be bound by
 * the terms of this license.
 * You must not remove this notice, or any other, from this software.
 *
 * The work contained herein is derived from and in many places is a direct translation 
 * of Clojure distribution <http://clojure.org/>. That work contains the following notice:
 *
 *   -----------------------------------------------------------------------------
 *   Clojure
 *   Copyright (c) Rich Hickey. All rights reserved.
 *   The use and distribution terms for this software are covered by the
 *   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
 *   which can be found in the file epl-v10.html at the root of this distribution.
 *   By using this software in any fashion, you are agreeing to be bound by
 *   the terms of this license.
 *   You must not remove this notice, or any other, from this software.
 *   -----------------------------------------------------------------------------
 */

#import "CTKPersistentHashMap.h"
#import "CTKTrieNode.h"
#import "CTKTrieEmptyNode.h"
#import "CTKTrieLeafNode.h"

@interface CTKPersistentHashMap ()

@property (readwrite, retain) id <CTKTrieNode> root;

@property (readwrite, assign) NSUInteger count;

@end


@implementation CTKPersistentHashMap

+ (id) emptyHashMap
{
	static CTKPersistentHashMap *sharedEmptyInstance;
	
	if(sharedEmptyInstance == nil){
		
		sharedEmptyInstance = [[CTKPersistentHashMap alloc] init];
	}
	
	return [[sharedEmptyInstance retain] autorelease];
}

+ (id) hashMapWithRoot:(id <CTKTrieNode>)aNode count:(NSUInteger)value
{
	return [[[CTKPersistentHashMap alloc] initWithRoot:aNode count:value] autorelease];
}

- (id) initWithRoot:(id <CTKTrieNode>)aNode count:(NSUInteger)value
{
	self = [super init];
	
	if(self != nil){
		
		self.root = aNode;
		self.count = value;
	}
	
	return self;
}

- (id) init
{
	return [self initWithRoot:[CTKTrieEmptyNode emptyNode]  
						count:0];
}

- (void) dealloc
{
	[root release];
	[super dealloc];
}


#pragma mark Properties

@synthesize root, count;

- (BOOL) containsObjectForKey:(id)aKey
{
	return [self entryForKey:aKey] != nil;
	
}

- (CTKPersistentHashMapEntry *) entryForKey:(id)aKey
{
	return (CTKPersistentHashMapEntry *)[self.root objectForKey:aKey hash:((aKey != nil) ? [aKey hash] : 0)];
}

- (id) objectForKey:(id)aKey
{
	return [[self entryForKey:aKey] object];
}

// assoc()
- (CTKPersistentHashMap *) mapBySettingObject:(id)anObject forKey:(id)aKey
{
	CTKTrieLeafNode *addedLeaf = nil;
	
	id <CTKTrieNode> newRoot = [self.root setObject:anObject
											 forKey:aKey
											  shift:0
											   hash:((aKey != nil) ? [aKey hash] : 0)
										  addedLeaf:&addedLeaf];
	
	if([newRoot isEqual:self.root])
		return self;
	
	
	NSUInteger theCount = (addedLeaf == nil) ? self.count : self.count + 1;
	
	return [CTKPersistentHashMap hashMapWithRoot:newRoot count:theCount];
}

// without()
- (CTKPersistentHashMap *) mapByRemovingObjectForKey:(id)aKey
{
	
	id <CTKTrieNode> newRoot = [self.root removeObjectForKey:aKey hash:((aKey != nil) ? [aKey hash] : 0)];
	
	if(newRoot == self.root)
		return self;
	
	if(newRoot == nil)
		return [CTKPersistentHashMap emptyHashMap];
	
	return [CTKPersistentHashMap hashMapWithRoot:newRoot count:self.count - 1];
}


- (NSArray *) allEntries
{
	return nil; // @TODO Implement
}


- (NSArray *) allValues
{
	return nil; // @TODO Implement

}

- (NSArray *) allKeys
{
	return nil; // @TODO Implement

}







@end
