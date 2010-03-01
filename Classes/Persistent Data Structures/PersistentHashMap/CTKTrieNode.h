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
#import "CTKSequential.h"
@class CTKTrieLeafNode;

/*
 
// http://infolab.stanford.edu/~manku/bitcount/bitcount.c
// Also see http://graphics.stanford.edu/~seander/bithacks.html
// Parallel Count algorithm
 */

static NSUInteger CTKBitCount(NSUInteger n)
{
	return (NSUInteger) __builtin_popcountll(n);
}

static NSUInteger const CTKTrieNodeShiftIncrement = 6;
static NSUInteger const CTKTrieNodeMaskCoeficient = 0x3f; //0x01f = 31 -> for 32 bit; 0x03f = 63 -> for 64 bit

/*!
 @function   private_mask
 @abstract   Extracts from the hashValue the 5-bit block corresponding to the shifValue level of the trie
 @discussion 
 @param      shiftValue - A shiftValue of 0 returns the first level, a shiftValue of 5 returns the 2nd level and so on.
 @result     <#(description)#>
 */
static NSUInteger CTKTrieNodeMask(NSUInteger hashValue, NSUInteger shiftValue)
{	
	/*
	 Performs a logical shift (not an arithmetical shift) because hashValue is unsigned
	*/
	return (hashValue >> shiftValue) & CTKTrieNodeMaskCoeficient; 
}

/*!
 @function   private_bitpos
 @abstract   Maps numbers [0, 63] to powers of two
 @discussion 
 @param      shiftValue - A shiftValue of 0 returns the first level, a shiftValue of 5 returns the 2nd level and so on.
 @result     <#(description)#>
 */
static NSUInteger CTKTrieNodeBitpos(NSUInteger hashValue, NSUInteger shiftValue)
{	
	NSUInteger mask = CTKTrieNodeMask(hashValue, shiftValue);
	return (NSUInteger)1 << mask;
}

// The index of a child is the number of 1’s to the right of the child’s bitpos in the bit map
static NSUInteger CTKTrieNodeIndex(NSUInteger bitmap, NSUInteger bit)
{
	return CTKBitCount(bitmap & (bit - 1));	
}

static NSString * CTKNSUIntegerToBinFormat(NSUInteger value)
{
	NSMutableString *str = [NSMutableString string];
	
	if(value == 0){
		[str insertString:@"0" atIndex:0];
		return [str autorelease];

	} 
	
	for(NSUInteger numberCopy = value; numberCopy > 0; numberCopy >>= 1)
	{
		// Prepend "0" or "1", depending on the bit
		[str insertString:((numberCopy & 1) ? @"1" : @"0") atIndex:0];
	}
	return [str autorelease];
}





/*!
    @protocol    CTKTrieNode <NSObject>
    @abstract    <#(brief description)#>
    @discussion  <#(comprehensive description)#>
*/
@protocol CTKTrieNode <NSObject>


@property (readonly, assign) NSUInteger hashValue;

// - (id <QLSequential>) nodeSequence;

/*!
    @method     objectForKey:hash:
    @abstract   Corresponds to the Clojure find method
    @discussion <#(comprehensive description)#>
    @param      aKey <#(description)#>
    @param      aHashValue <#(description)#>
    @result     <#(description)#>
*/
- (CTKTrieLeafNode *) objectForKey:(id)aKey hash:(NSUInteger)aHashValue;

/*!
    @method     setObject:forKey:shift:hash:addedLeaf:
    @abstract   Corresponds to the Clojure assoc method
    @discussion <#(comprehensive description)#>
    @param      anObject <#(description)#>
    @param      aKey <#(description)#>
    @param      aShiftValue <#(description)#>
    @param      aHashValue <#(description)#>
    @param      aLeaf <#(description)#>
    @result     <#(description)#>
*/
- (id <CTKTrieNode>) setObject:(id)anObject 
						forKey:(id)aKey 
						 shift:(NSUInteger)aShiftValue 
						  hash:(NSUInteger)aHashValue
					 addedLeaf:(CTKTrieLeafNode **)aLeaf;

/*!
    @method     removeObjectForKey:hash:
    @abstract   Corresponds to the Clojure without method
    @discussion <#(comprehensive description)#>
    @param      aKey <#(description)#>
    @param      aHashValue <#(description)#>
    @result     <#(description)#>
*/
- (id <CTKTrieNode>) removeObjectForKey:(id)aKey hash:(NSUInteger)aHashValue;


@end
