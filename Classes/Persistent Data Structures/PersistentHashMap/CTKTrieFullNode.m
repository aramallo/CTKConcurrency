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

#import "CTKTrieFullNode.h"
#import "CTKTrieLeafNode.h"
#import "CTKTrieBitmapIndexedNode.h"

@interface CTKTrieFullNode ()

@property (readwrite, assign) NSUInteger hashValue;
@property (readwrite, retain) NSArray *nodes;
@property (readwrite, assign) NSUInteger shift;

@end




@implementation CTKTrieFullNode

+ (id) fullNodeWithNodes:(NSArray *)anArray shift:(NSUInteger)aShiftValue
{
	return [[[CTKTrieFullNode alloc] initWithNodes:anArray shift:aShiftValue] autorelease];
}

- (id) initWithNodes:(NSArray *)anArray shift:(NSUInteger)aShiftValue
{
	//NSLog(@"+++ [%@] %s. | count:%U", [self class], _cmd, [anArray count]);

	self = [super init];
	
	if (self != nil) {
		self.nodes = anArray;
		self.shift = aShiftValue;
		self.hashValue = [(id <CTKTrieNode>)[self.nodes objectAtIndex:0] hashValue];
	}
	
	return self;
	
}

- (void) dealloc
{
	[nodes release];
	
	[super dealloc];
}


#pragma mark Properties

@synthesize nodes, hashValue, shift;

#pragma mark CTKTrieNode


- (CTKTrieLeafNode *) objectForKey:(id)aKey hash:(NSUInteger)aHashValue
{	
	id <CTKTrieNode> theNode =  [self.nodes objectAtIndex: CTKTrieNodeMask(aHashValue, self.shift)];
	
	return [theNode objectForKey:aKey hash:aHashValue];
}

- (id <CTKTrieNode>) setObject:(id)anObject 
						forKey:(id)aKey 
						 shift:(NSUInteger)aShiftValue 
						  hash:(NSUInteger)aHashValue
					 addedLeaf:(CTKTrieLeafNode **)aLeaf
{
	//NSLog(@"+++ [%@] %s.\nCalled with object:%@ key:%@ shift:%U hash:%U", [self class], _cmd, anObject, aKey, aShiftValue, aHashValue);
	
	NSUInteger index = CTKTrieNodeMask(aHashValue, self.shift);
	
	id <CTKTrieNode> existingNode = [self.nodes objectAtIndex:index];
	id <CTKTrieNode> newNode = [existingNode setObject:anObject
												forKey:aKey
												 shift:(self.shift + CTKTrieNodeShiftIncrement)
												  hash:aHashValue
											 addedLeaf:aLeaf];
	
	if(newNode != existingNode){
		
		NSMutableArray *newNodes = [NSMutableArray arrayWithArray:self.nodes];
		[newNodes replaceObjectAtIndex:index withObject:newNode];
		
		return [CTKTrieFullNode fullNodeWithNodes:newNodes shift:self.shift];
		
	}
	
	return self;

}

- (id <CTKTrieNode>) removeObjectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	
	NSUInteger index = CTKTrieNodeMask(aHashValue, self.shift);
	id <CTKTrieNode> existingNode = [self.nodes objectAtIndex:index];

	id <CTKTrieNode> newNode = [existingNode removeObjectForKey:aKey hash:aHashValue];
	
	if(newNode != existingNode){
		
		NSMutableArray *newNodes = [NSMutableArray arrayWithArray:self.nodes];

		if(newNode == nil){
			
			[newNodes removeObjectAtIndex:index];
			NSUInteger newBitmap = ~CTKTrieNodeBitpos(aHashValue, self.shift);
			
			return [CTKTrieBitmapIndexedNode bitmapIndexedNodeWithNodes:newNodes
																 bitmap:newBitmap
																  shift:self.shift];
		}
		
		[newNodes replaceObjectAtIndex:index withObject:newNode];
		
		return [CTKTrieFullNode fullNodeWithNodes:newNodes shift:self.shift];
	}
	
	return self;
}


@end
