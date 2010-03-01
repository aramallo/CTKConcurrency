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

#import "CTKTrieHashCollisionNode.h"
#import "CTKTrieBitmapIndexedNode.h"
#import "CTKTrieLeafNode.h"

@interface CTKTrieHashCollisionNode ()

@property (readwrite, retain) NSArray *leaves;
@property (readwrite, assign) NSUInteger hashValue;

@end


@implementation CTKTrieHashCollisionNode


+ (id) hashCollisionNodeWithLeaves:(NSArray *)anArray hash:(NSUInteger)aHashValue
{
	return [[[CTKTrieHashCollisionNode alloc] initWithLeaves:anArray 
												   hash:aHashValue] autorelease];
}

- (id) initWithLeaves:(NSArray *)anArray hash:(NSUInteger)aHashValue
{
	//NSLog(@"+++ [%@] %s.\nCalled with array:%@ hash:%U", [self class], _cmd, anArray, aHashValue);
	self = [super init];
	
	if(self != nil){
		self.leaves = anArray;
		self.hashValue = aHashValue;
	}
	
	return self;
}

- (void) dealloc
{
	[leaves release];
	[super dealloc];
}


#pragma mark Properties

@synthesize hashValue, leaves;


#pragma mark Operations

- (CTKTrieLeafNode *) objectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	
	NSUInteger idx = [self indexOfObjectForKey:aKey hash:aHashValue];
	
	if(idx != NSNotFound)
		return [self.leaves objectAtIndex:idx];
	
	return nil;
	
}

- (id <CTKTrieNode>) setObject:(id)anObject 
						forKey:(id)aKey 
						 shift:(NSUInteger)aShiftValue 
						  hash:(NSUInteger)aHashValue
					 addedLeaf:(CTKTrieLeafNode **)aLeaf
{
	
	//NSLog(@"+++ [%@] %s.\nCalled with object:%@ key:%@ shift:%U hash:%U", [self class], _cmd, anObject, aKey, aShiftValue, aHashValue);
	
	if(aHashValue == self.hashValue){
		
		NSUInteger idx = [self indexOfObjectForKey:aKey hash:aHashValue];
		NSMutableArray *newLeaves = [NSMutableArray arrayWithArray:self.leaves];
		CTKTrieLeafNode *newLeaf = [CTKTrieLeafNode leafNodeWithObject:anObject forKey:aKey hash:aHashValue];
		
		//note  - do not set addedLeaf yet, since we might be replacing
		
		if(idx != NSNotFound){
			
			if([[[self.leaves objectAtIndex:idx] object] isEqual:anObject])
				return self;
			
			[newLeaves replaceObjectAtIndex:idx withObject:newLeaf];
			return [CTKTrieHashCollisionNode hashCollisionNodeWithLeaves:newLeaves hash:aHashValue];
		}
		
		[newLeaves addObject:newLeaf];
		
		if(aLeaf != NULL)
			*aLeaf = newLeaf;
		
		return [CTKTrieHashCollisionNode hashCollisionNodeWithLeaves:newLeaves hash:aHashValue];
		
	}
	
	return [CTKTrieBitmapIndexedNode nodeWithObject:anObject
										forKey:aKey
										branch:self
										 shift:aShiftValue
										  hash:aHashValue
									 addedLeaf:aLeaf];
}

- (id <CTKTrieNode>) removeObjectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	
	NSUInteger idx = [self indexOfObjectForKey:aKey hash:aHashValue];
	
	if(idx == NSNotFound)
		return self;
	
	if([self.leaves count] == 2)
		return (idx == 0) ? [self.leaves objectAtIndex:1] : [self.leaves objectAtIndex:0];
	
	NSMutableArray *newLeaves = [NSMutableArray arrayWithArray:self.leaves];
	[newLeaves removeObjectAtIndex:idx];
	
	return [CTKTrieHashCollisionNode hashCollisionNodeWithLeaves:newLeaves hash:aHashValue];
	
}


- (NSUInteger) indexOfObjectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	NSUInteger idx = 0;
	
	for(id leaf in self.leaves){
		
		if([leaf objectForKey:aKey hash:aHashValue] != nil)
			return idx;
		
		idx++;
	}
	
	return NSNotFound;
}

@end
