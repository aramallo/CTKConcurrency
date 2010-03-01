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

#import "CTKTrieEmptyNode.h"
#import "CTKTrieLeafNode.h"

@interface CTKTrieEmptyNode ()

@property (readwrite, assign) NSUInteger hashValue;


@end

@implementation CTKTrieEmptyNode


+ (id) emptyNode
{
	return [[CTKTrieEmptyNode new] autorelease];
}

#pragma mark Properties

@dynamic hashValue;

- (NSUInteger) hashValue
{
	return 0;
}

#pragma mark Operations


- (CTKTrieLeafNode *) objectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	return nil;
}

- (id <CTKTrieNode>) setObject:(id)anObject 
						forKey:(id)aKey 
						 shift:(NSUInteger)aShiftValue 
						  hash:(NSUInteger)aHashValue
					 addedLeaf:(CTKTrieLeafNode **)aLeaf
{
	//NSLog(@"+++ [%@] %s.\nCalled with object:%@ key:%@ shift:%U hash:%U", [self class], _cmd, anObject, aKey, aShiftValue, aHashValue);
	
	CTKTrieLeafNode *ret = [CTKTrieLeafNode leafNodeWithObject:anObject forKey:aKey hash:aHashValue];
	
	if(aLeaf != NULL)
		*aLeaf = ret;
	
	return ret;
}

- (id <CTKTrieNode>) removeObjectForKey:(id)aKey hash:(NSUInteger)aHashValue
{
	return self;
}


@end
