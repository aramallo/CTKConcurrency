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

#import "CTKTrieBitmapIndexedNode.h"
#import "CTKTrieLeafNode.h"
#import "CTKTrieFullNode.h"

#pragma mark Util Functions

@interface CTKTrieBitmapIndexedNode ()

@property (readwrite, assign) NSUInteger hashValue;
@property (readwrite, retain) NSArray *nodes;
@property (readwrite) NSUInteger bitmap;
@property (readwrite) NSUInteger shift;

@end

@interface CTKTrieBitmapIndexedNode (Private)

- (id <CTKTrieNode>) private_nodeFromExistingNodeWithObject:(id)anObject
													 forKey:(id)aKey
													   hash:(NSUInteger)aHashValue
												  addedLeaf:(CTKTrieLeafNode **)aLeaf;

- (id <CTKTrieNode>) private_nodeByAddingLeafNodeWithObject:(id)anObject 
													 forKey:(id)aKey 
													   hash:(NSUInteger)aHashValue
												  addedLeaf:(CTKTrieLeafNode **)aLeaf;
@end


@implementation CTKTrieBitmapIndexedNode

#pragma mark Initialization

+ (id <CTKTrieNode>) nodeWithObject:(id)anObject
							 forKey:(id)aKey
							 branch:(id <CTKTrieNode>)aBranch
							  shift:(NSUInteger)aShiftValue 
							   hash:(NSUInteger)aHashValue
						  addedLeaf:(CTKTrieLeafNode **)aLeaf
{
	//NSLog(@"+++ [%@] %s.\nCalled with object:%@ key:%@ branch:%@ shift:%U hash:%U", [self class], _cmd, anObject, aKey, aBranch, aShiftValue, aHashValue);
	NSParameterAssert(aBranch);
	
	CTKTrieBitmapIndexedNode *node =  [self bitmapIndexedNodeWithNodes:[NSArray arrayWithObject:aBranch]
																bitmap:CTKTrieNodeBitpos(aBranch.hashValue, aShiftValue)
																 shift:aShiftValue];
	
	return [node setObject:anObject forKey:aKey shift:aShiftValue hash:aHashValue addedLeaf:aLeaf];
}

+ (id) bitmapIndexedNodeWithNodes:(NSArray *)anArray 
						   bitmap:(NSUInteger)aBitmap 
							shift:(NSUInteger)aShiftValue
{
	//NSLog(@"+++ [%@] %s.\nCalled with array:%@ bitmap:%U shift:%U", [self class], _cmd, anArray, aBitmap, aShiftValue);
	
	
	return [[[self alloc] initWithNodes:anArray
								 bitmap:aBitmap
								  shift:aShiftValue] autorelease];
}


- (id) initWithNodes:(NSArray *)anArray bitmap:(NSUInteger)aBitmap shift:(NSUInteger)aShiftValue
{
	NSParameterAssert(anArray);
	/*
	NSLog(@"+++ [%@] %s. count:%U (%U) bitmap:%@ shift:%U", [self class], _cmd, [anArray count], CTKBitCount(aBitmap), CTKNSUIntegerToBinFormat(aBitmap), aShiftValue);
	 */
	
	self = [super init];
	
	if(self != nil){
		self.bitmap = aBitmap;
		self.shift = aShiftValue;
		self.nodes = anArray;
		self.hashValue = [(id <CTKTrieNode>)[anArray objectAtIndex:0] hashValue];
	}
	
	//NSLog(@"+++ [%@] %s.\nCreated with bitmap:%U shift:%U hash:%U", [self class], _cmd, self.bitmap, self.shift, self.hashValue);
	
	
	return self;
}

- (void) dealloc
{
	[nodes release];
	[super dealloc];
}


#pragma mark Properties


@synthesize hashValue, bitmap, shift, nodes;

#pragma mark CTKTrieNode protocol


- (CTKTrieLeafNode *) objectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	NSUInteger bit = CTKTrieNodeBitpos(aHashValue, self.shift);
	NSUInteger index = CTKTrieNodeIndex(self.bitmap, bit);
	
	if((self.bitmap & bit) != 0)
	{
		id <CTKTrieNode> node = [self.nodes objectAtIndex:index];
		
		return [node objectForKey:aKey hash:aHashValue];
	}
	
	return nil;
}

- (id <CTKTrieNode>) setObject:(id)anObject 
						forKey:(id)aKey 
						 shift:(NSUInteger)aShiftValue 
						  hash:(NSUInteger)aHashValue
					 addedLeaf:(CTKTrieLeafNode **)aLeaf
{
	
	//NSLog(@"+++ [%@] %s.\n -> count:%U", [self class], _cmd, [self.nodes count]);
	
	/*
	 We are not using the levelShift
	 */
	
	NSUInteger bit = CTKTrieNodeBitpos(aHashValue, self.shift);
	BOOL nodeShouldExist = (self.bitmap & bit) != 0;
	
	if(nodeShouldExist){
		
		return [self private_nodeFromExistingNodeWithObject:anObject
													 forKey:aKey
													   hash:aHashValue
												  addedLeaf:aLeaf];
	} 
	
	return [self private_nodeByAddingLeafNodeWithObject:anObject 
												 forKey:aKey 
												   hash:aHashValue 
											  addedLeaf:aLeaf];
}

- (id <CTKTrieNode>) private_nodeFromExistingNodeWithObject:(id)anObject
													 forKey:(id)aKey
													   hash:(NSUInteger)aHashValue
												  addedLeaf:(CTKTrieLeafNode **)aLeaf
{
	NSUInteger bit = CTKTrieNodeBitpos(aHashValue, self.shift);
	NSUInteger index = CTKTrieNodeIndex(self.bitmap, bit);
	
	id <CTKTrieNode> existingNode = [self.nodes objectAtIndex:index];
	
	if(existingNode == nil){
		
		NSString *reason = [NSString stringWithFormat:
							@"InvalidState, node does not contain object at index %U", index];
		@throw [NSException exceptionWithName:@"InvalidState" reason:reason userInfo:nil];
		
	}
	
	id <CTKTrieNode> newNode = [existingNode setObject:anObject
												forKey:aKey
												 shift:(self.shift + CTKTrieNodeShiftIncrement)
												  hash:aHashValue 
											 addedLeaf:aLeaf];
	
	if(newNode == existingNode){
		return self;
	}
	
	NSMutableArray *newNodes = [NSMutableArray arrayWithArray:self.nodes];
	[newNodes replaceObjectAtIndex:index withObject:newNode];
	
	//NSLog(@"+++ [%@] %s.\n <- count:%U verif(%U)", [self class], _cmd, [newNodes count], CTKBitCount(self.bitmap));

	return [CTKTrieBitmapIndexedNode bitmapIndexedNodeWithNodes:newNodes
														 bitmap:self.bitmap
														  shift:self.shift];
}

- (id <CTKTrieNode>) private_nodeByAddingLeafNodeWithObject:(id)anObject 
													 forKey:(id)aKey 
													   hash:(NSUInteger)aHashValue
												  addedLeaf:(CTKTrieLeafNode **)aLeaf

{
	NSUInteger bit = CTKTrieNodeBitpos(aHashValue, self.shift);
	NSUInteger index = CTKTrieNodeIndex(self.bitmap, bit);
	
	NSMutableArray *newNodes = [NSMutableArray arrayWithArray:self.nodes];
	CTKTrieLeafNode *newNode = [CTKTrieLeafNode leafNodeWithObject:anObject forKey:aKey hash:aHashValue];	
	[newNodes insertObject:newNode atIndex:index];
	
	if(aLeaf != NULL)
		*aLeaf = newNode;
	
	NSUInteger newBitmap = (self.bitmap | bit); // we denote the addition of a new node

	// (newBitmap) aBitmap == -1
	// CTKBitCount(newBitmap) == CTKTrieNodeMaskCoeficient + 1
	return (CTKBitCount(newBitmap) >= 64) 
	? [CTKTrieFullNode fullNodeWithNodes:newNodes shift:self.shift]
	: [CTKTrieBitmapIndexedNode bitmapIndexedNodeWithNodes:newNodes bitmap:newBitmap shift:self.shift];
}

- (id <CTKTrieNode>) removeObjectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	
	NSUInteger bit = CTKTrieNodeBitpos(aHashValue, self.shift);
	BOOL nodeShouldExist = (self.bitmap & bit) != 0;

	if(nodeShouldExist){
		
		NSUInteger index = CTKTrieNodeIndex(self.bitmap, bit);
		
		id <CTKTrieNode> existingNode = [self.nodes objectAtIndex:index];
		
		if(existingNode == nil){
			
			NSString *reason = [NSString stringWithFormat:
								@"Node does not contain object at index %U", index];
			
			@throw [NSException exceptionWithName:@"InvalidState" reason:reason userInfo:nil];
			
		}
		
		id <CTKTrieNode> newNode = [existingNode removeObjectForKey:aKey hash:aHashValue];
		
		if(newNode != existingNode){
			
			if(newNode == nil){
				
				if(self.bitmap == bit)
					return nil;
				
				NSMutableArray *newNodes = [NSMutableArray arrayWithArray:self.nodes];
				[newNodes removeObjectAtIndex:index];
				
				NSUInteger newBitmap = (self.bitmap & ~bit);
				
				return [CTKTrieBitmapIndexedNode bitmapIndexedNodeWithNodes:newNodes
																	 bitmap:newBitmap
																	  shift:self.shift];
				
			}
			
			NSMutableArray *newNodes = [NSMutableArray arrayWithArray:self.nodes];
			[newNodes replaceObjectAtIndex:index withObject:newNode];
			
			return [CTKTrieBitmapIndexedNode bitmapIndexedNodeWithNodes:newNodes
																 bitmap:self.bitmap
																  shift:self.shift];
		}
	}
	
	return self;
}




@end
