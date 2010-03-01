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

#import <Cocoa/Cocoa.h>
#import "CTKTrieNode.h"
@class CTKTrieLeafNode;
@class CTKSparseArray;

@interface CTKTrieBitmapIndexedNode : NSObject <CTKTrieNode> {
    @private
	NSUInteger bitmap;
	NSArray *nodes;
	NSUInteger shift;
	NSUInteger hashValue;
}

@property (readonly, retain) NSArray *nodes; // was copy
/*
 The bitmap tells us how many children this node has, and also what their indexes are in the child array. 
 The bit-map has a binary representation, e.g. 00000000000000010000000010000101.
 
 The number of children is the number of 1’s in the binary representation. 
 If the nth bit in bitmap is 1 (counting right-to-left, starting with position 0) then there is a child with index n. 
 So to check if a child exists for a certain hash-code: first compute mask(hash,shift) to get the bit-block and number in
 range [0, 31]. Then compute bitpos of this. You then have a number of form 10n. Now match that with the bitmap to check
 if there is a 1 in the n‘th position; this match is simply a bit-wise and, ‘&’, with bitpos.
 */
@property (readonly) NSUInteger bitmap;
@property (readonly) NSUInteger shift;


+ (id <CTKTrieNode>) nodeWithObject:(id)anObject
							 forKey:(id)aKey
							 branch:(id <CTKTrieNode>)aBranch
							  shift:(NSUInteger)aShiftValue 
							   hash:(NSUInteger)aHashValue
						  addedLeaf:(CTKTrieLeafNode **)aLeaf;

+ (id) bitmapIndexedNodeWithNodes:(NSArray *)anArray bitmap:(NSUInteger)aBitmap shift:(NSUInteger)aShiftValue;

- (id) initWithNodes:(NSArray *)anArray bitmap:(NSUInteger)aBitmap shift:(NSUInteger)aShiftValue;


@end
