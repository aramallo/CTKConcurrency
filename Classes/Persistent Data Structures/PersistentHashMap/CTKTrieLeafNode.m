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

#import "CTKTrieLeafNode.h"
#import "CTKTrieHashCollisionNode.h"
#import "CTKTrieBitmapIndexedNode.h"

@interface CTKTrieLeafNode ()

@property (readwrite, assign) NSUInteger hashValue;

@end

@implementation CTKTrieLeafNode

+ (id) leafNodeWithObject:(id)anObject forKey:(id)aKey hash:(NSUInteger)aHashValue
{
	return [[[CTKTrieLeafNode alloc] initWithObject:anObject forKey:aKey hash:aHashValue] autorelease];
}

- (id) initWithObject:(id)anObject forKey:(id)aKey hash:(NSUInteger)aHashValue
{
	//NSLog(@"+++ [%@] %s.\nCalled with object:%@ key:%@ hash:%U", [self class], _cmd, anObject, aKey, aHashValue);
	
	self = [super initWithObject:anObject forKey:aKey];
	
	if (self != nil) {
		self.hashValue = aHashValue;
	}
	
	return self;
}


@synthesize hashValue;


- (CTKTrieLeafNode *) objectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	if(aHashValue == [self hashValue] && [self.key isEqual:aKey])
		return self;
	
	//NSLog(@"+++ [%@] %s.Will return nil.", [self class], _cmd);
	
	return nil;
}

- (id <CTKTrieNode>) setObject:(id)anObject 
						forKey:(id)aKey 
						 shift:(NSUInteger)aShiftValue 
						  hash:(NSUInteger)aHashValue
					 addedLeaf:(CTKTrieLeafNode **)aLeaf
{	
	//NSLog(@"+++ [%@] %s.\nCalled with object:%@ key:%@ shift:%U hash:%U", [self class], _cmd, anObject, aKey, aShiftValue, aHashValue);
	
	//NSLog(@"+++ [%@] %s.\nself.hashValue:%U key:%@", [self class], _cmd, self.hashValue, self.key);
	
	if(aHashValue == [self hashValue]){
		
		if([aKey isEqual:self.key]){
			
			if([anObject isEqual:self.object])
				return self;
			
			/* 
			 We do not set aLeaf, since I am replacing myself with a new leaf node containing
			 another object for the same key.
			 */
			
			//NSLog(@"+++ [%@] %s.\nWill return a replacement leaf", [self class], _cmd);
			
			return [CTKTrieLeafNode leafNodeWithObject:anObject forKey:aKey hash:aHashValue];
		}
		
		else {
			
			/*
			 We have a hash collision - same hash but different keys.
			 I will replace myself with a hash collision node.
			 */
			
			CTKTrieLeafNode *newLeaf = [CTKTrieLeafNode leafNodeWithObject:anObject forKey:aKey hash:aHashValue];
			
			if(aLeaf != NULL)
				*aLeaf = newLeaf;
			
			NSArray *leaves = [NSArray arrayWithObjects:self, newLeaf, nil];
			
			return [CTKTrieHashCollisionNode hashCollisionNodeWithLeaves:leaves 
																	hash:aHashValue];
		}
	}
		
	/* 
	 This is a new entry so I will replace myself with a bitmap node 
	 */
	return [CTKTrieBitmapIndexedNode nodeWithObject:anObject
											 forKey:aKey
											 branch:self
											  shift:aShiftValue 
											   hash:aHashValue
										  addedLeaf:aLeaf];
	
}

- (id <CTKTrieNode>) removeObjectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	if(aHashValue == [self hashValue] && [self.key isEqual:aKey])
		return nil;
	
	return self;
}

@end
